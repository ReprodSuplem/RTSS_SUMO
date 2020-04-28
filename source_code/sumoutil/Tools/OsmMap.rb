#! /usr/bin/env ruby
## -*- mode: ruby -*-
## = OsmMap scanner
## Author:: Anonymous3
## Version:: 0.0 2018/08/16 Anonymous3
##
## === History
## * [2018/08/16]: Create This File.
## * [YYYY/MM/DD]: add more
## == Usage
## * ...

def $LOAD_PATH.addIfNeed(path)
  self.unshift(path) if(!self.include?(path)) ;
end

$LOAD_PATH.addIfNeed("~/lib/ruby");
# $LOAD_PATH.addIfNeed(File.dirname(__FILE__));

require 'optparse' ;
require 'pp' ;
require 'ox' ;

#--======================================================================
#++
## description of class Foo.
class OsmMap
  #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  #++
  ## description of DefaultValues.
  DefaultValues = { :foo => :bar } ;
  ## description of DefaultOptsions.
  DefaultConf = { :bar => :baz } ;

  ## Savs PoI tag name
  Tag_SavsPoi = "savs:poi" ;
  ## Savs zone tag name
  Tag_SavsZone = "savs:zone" ;

  #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  #++
  ## XML document
  attr_accessor :xml ;
  ## the table of node
  attr_accessor :nodeTable ;
  ## the table of way
  attr_accessor :wayTable ;
  ## the table of relation
  attr_accessor :relationTable ;

  ## removed way list
  attr_accessor :removedWayList ;
  
  ## the table of nodes with SAVS tag
  attr_accessor :savsPoiList ;
  ## the table of zone with SAVS tag
  attr_accessor :savsZoneList ;
  
  #--------------------------------------------------------------
  #++
  ## initialize OsmMap
  ## _xml_:: xml document (in Ox)
  def initialize(_xml = nil)
    setXml(_xml) ;
    @nodeTable = {} ;
    @wayTable = {} ;
    @relationTable = {} ;
    @removedWayList = [] ;
  end

  #--------------------------------------------------------------
  #++
  ## set Xml Document
  ## _xml_:: Xml Document in Ox
  ## *return*:: @xml
  def setXml(_xml)
    @xml = _xml ;
  end
  
  #--------------------------------------------------------------
  #++
  ## scan Xml String and set
  ## _str_:: XmlString
  ## *return*:: scanned xml document
  def readXmlString(_str)
    setXml(Ox.parse(_str)) ;
  end

  #--------------------------------------------------------------
  #++
  ## load Xml from stream
  ## _strm_:: stream of Xml file
  ## *return*:: scanned xml document
  def readXmlStream(_strm)
    readXmlString(_strm.read) ;
  end
  
  #--------------------------------------------------------------
  #++
  ## load Xml File
  ## _str_:: XmlString
  ## *return*:: scanned xml document
  def readXmlFile(_file)
    open(_file,"r"){|strm|
      readXmlStream(strm) ;
    }
  end

  #--------------------------------------------------------------
  #++
  ## scan Xml to build tables
  def scanXml()
    if(!@xml.nil?) then
      scanXmlNodes() ;
      scanXmlWays() ;
      scanXmlRelations() ;
      dereference() ;
    end
  end

  #--------------------------------------------------------------
  #++
  ## scan node elements
  def scanXmlNodes()
    @xml.locate("osm/node").each{|nodeXml|
      node = Node.new(nodeXml) ;
      @nodeTable[node.id] = node ;
    }
  end
  
  #--------------------------------------------------------------
  #++
  ## scan way elements
  def scanXmlWays()
    @xml.locate("osm/way").each{|wayXml|
      way = Way.new(wayXml) ;
      @wayTable[way.id] = way ;
    }
  end
  
  #--------------------------------------------------------------
  #++
  ## scan way elements
  def scanXmlRelations()
    @xml.locate("osm/relation").each{|relXml|
      rel = Relation.new(relXml) ;
      @relationTable[rel.id] = rel ;
    }
  end

  #--------------------------------------------------------------
  #++
  ## dereference of ways and relations
  def dereference()
    @wayTable.each{|k, way|
      way.dereference(self) ;
    }
    @relationTable.each{|k, rel|
      rel.dereference(self) ;
    }
  end
  
  #--------------------------------------------------------------
  #++
  ## remove footway
  def removeTroublesomeWays()
    removeFootway() ;
    removeDeadEndOneway() ;
  end
  #--------------------------------------------------------------
  #++
  ## remove footway
  def removeFootway()
    removedSubList = removeWayIf(){|way| way.isFootway()} ;
    
    return removedSubList ;
  end
  
  #--------------------------------------------------------------
  #++
  ## remove dead-end oneways.
  def removeDeadEndOneway()
    removedSubList = nil ;

    begin
      removedSubList = removeWayIf(){|way| way.isDeadEndOneway()} ;
    end while(removedSubList.size > 0) ;
  end
  
  #--------------------------------------------------------------
  #++
  ## remove dead-end oneways.
  def removeWayIf(&block)
    removedSubList = [] ;
    @wayTable.each{|id, way|
      removeWay(way, removedSubList) if(block.call(way)) ;
    }
    removedSubList.each{|way|
      @wayTable.delete(way.id) ;
    }
    return removedSubList ;
  end
  
  #--------------------------------------------------------------
  #++
  ## remove dead-end oneways.
  def removeWay(way, subList)
    way.nodeList.each{|node|
      node.removeWay(way) ;
    }
    subList.push(way) ;
    @removedWayList.push(way) ;
  end
    
  #--------------------------------------------------------------
  #++
  ## scan SAVS tagged elements
  def scanSavsTags()
    scanSavsTags_Poi() ;
    scanSavsTags_Zone() ;
  end
  
  #--------------------------------------------------------------
  #++
  ## scan SAVS PoI
  def scanSavsTags_Poi()
    @savsPoiList = [] ;
    
    @nodeTable.each{|key,node|
      @savsPoiList.push(node) if(!node.tag[Tag_SavsPoi].nil?) ;
    }

    return @savsPoiList ;
  end
  
  #--------------------------------------------------------------
  #++
  ## scan SAVS Zone
  def scanSavsTags_Zone()
    @savsZoneList = [] ;
    
    @relationTable.each{|key,rel|
      @savsZoneList.push(rel) if(!rel.tag[Tag_SavsZone].nil?) ;
    }
    @wayTable.each{|key,way|
      @savsZoneList.push(way) if(!way.tag[Tag_SavsZone].nil?) ;
    }

    return @savsZoneList ;
  end

  #--------------------------------------------------------------
  #++
  ## convert to Json for Savs
  def toJson_Savs()
    json = {} ;
    json[:savsPoi] = toJson_SavsPoi() ;
    json[:savsZone] = toJson_SavsZone() ;

    return json ;
  end

  #--------------------------------------------------------------
  #++
  ## convert to Json for Savs
  def toJson_SavsPoi()
    @savsPoiList.map{|poi| poi.toJson() ;}
  end

  #--------------------------------------------------------------
  #++
  ## convert to Json for Savs
  def toJson_SavsZone()
    @savsZoneList.map{|zone| zone.toJson() ;}
  end
  
  #--============================================================
  #++
  ## OsmMap::TaggedObject
  class TaggedObject
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## original xml
    attr_accessor :xml ;
    ## id
    attr_accessor :id ;
    ## table of tag
    attr_accessor :tag ;
    
    #------------------------------------------
    #++
    ## setId
    def setId(_xml)
      @id = _xml['id'] ;
    end

    #------------------------------------------
    #++
    ## scanTags
    def scanTags(_xml)
      @tag = {} ;
      _xml.locate("tag").each{|_tag|
        @tag[_tag["k"]] = _tag["v"] ;
      }
      return @tag ;
    end

    #------------------------------------------
    #++
    ## scanTags
    def scanXml(_xml)
      @xml = _xml ;
      setId(_xml) ;
      scanTags(_xml) ;
      return self ;
    end

    #------------------------------------------
    #++
    ## convert to Json
    def toJson()
      json = { :id => @id,
               :tag => @tag } ;
      return json ;
    end
    
  end # class OsmMap::TaggedObject
    
  #--============================================================
  #++
  ## OsmMap::Node class
  class Node < TaggedObject
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## lonlat
    attr_accessor :lonlat ;
    ## way list
    attr_accessor :wayList ;

    #------------------------------------------
    #++
    ## initialize
    def initialize(_xml)
      @wayList = [] ;
      scanXml(_xml) ;
    end
    
    #------------------------------------------
    #++
    ## initialize
    def scanXml(_xml)
      super(_xml) ;
      @lonlat = [_xml['lon'].to_f, _xml['lat'].to_f] ;
      return self ;
    end

    #------------------------------------------
    #++
    ## add way
    def addWay(_way)
      @wayList.push(_way) ;
    end
    
    #------------------------------------------
    #++
    ## remove way
    def removeWay(_way)
      @wayList.delete(_way) ;
    end

    #------------------------------------------
    #++
    ## check dead-end
    def isDeadEnd()
      return (@wayList.size <= 1) ;
    end
    
    #------------------------------------------
    #++
    ## convert to Json
    def toJson()
      json = super() ;
      json[:type] = 'node' ;
      json[:lonlat] = @lonlat ;
      return json ;
    end
    
  end # class OsmMap::Node

  #--============================================================
  #++
  ## OsmMap::Way
  class Way < TaggedObject
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## list of node
    attr_accessor :nodeList ;

    #------------------------------------------
    #++
    ## initialize
    def initialize(_xml)
      scanXml(_xml)
    end
    
    #------------------------------------------
    #++
    ## initialize
    def scanXml(_xml)
      super(_xml) ;
      @nodeList = [] ;
      _xml.locate("nd").each{|_node|
        ref = _node["ref"] ;
        @nodeList.push(ref) ;
      }
      return self ;
    end
    
    #------------------------------------------
    #++
    ## initialize
    def dereference(_map)
      (0...@nodeList.size).each{|i|
        ref = @nodeList[i] ;
        node = _map.nodeTable[ref] ;
        @nodeList[i] = node ;
        node.addWay(self) ;
      }
      return self ;
    end
      
    #------------------------------------------
    #++
    ## convert to Json
    def getLonLat()
      @nodeList.map{|node| node.lonlat ; }
    end

    #------------------------------------------
    #++
    ## check one way
    def isOneway()
      @tag.each{|k, v|
        if(k == "oneway") then
          return (v == "yes") ;
        end
      }
      return false ;
    end

    #------------------------------------------
    #++
    ## check one way
    def isDeadEnd()
      return true if(@nodeList.size == 0) ;
      return ((@nodeList.first.isDeadEnd()) ||
              (@nodeList.last.isDeadEnd())) ;
    end
    
    #------------------------------------------
    #++
    ## check one way
    def isDeadEndOneway()
      return isOneway() && isDeadEnd() ;
    end
    
    #------------------------------------------
    #++
    ## check one way
    def isFootway()
      @tag.each{|k, v|
        if(k == "highway") then
          return (v == "footway") ;
        end
      }
      return false ;
    end
    #------------------------------------------
    #++
    ## convert to Json
    def toJson()
      json = super() ;
      json[:type] = 'way' ;
      json[:poi] = @tag[Tag_SavsPoi] ;
      lonlat = getLonLat() ;
      json[:lonlat] = lonlat ;
      
      return json ;
    end
    
  end # class OsmMap::Way

  #--============================================================
  #++
  ## OsmMap::Relation
  class Relation < TaggedObject
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## list of node
    attr_accessor :memberList ;

    #------------------------------------------
    #++
    ## initialize
    def initialize(_xml, _map = nil)
      scanXml(_xml) ;
    end
    
    #------------------------------------------
    #++
    ## initialize
    def scanXml(_xml) 
      super(_xml) ;
      @memberList = [] ;
      _xml.locate("member").each{|_member|
        obj = {} ;
        obj[:type] = _member['type'] ;
        obj[:ref] = _member['ref'] ;
        obj[:role] = _member['role'] ;
        
        @memberList.push(obj) ;
      }
      return self ;
    end

    #------------------------------------------
    #++
    ## dereference
    def dereference(_map)
      @memberList.each{|member|
        obj = nil ;
        type = member[:type] ;
        ref = member[:ref] ;
        case(type)
        when("way") ;
          obj = _map.wayTable[ref] ;
        when("node") ;
          obj = _map.nodeTable[ref] ;
        when("relation") ;
          obj = _map.relationTable[ref] ;
        else
          raise "unknown member type:" + type ;
        end
        member[:obj] = obj ;
      }
      return self ;
    end
    
    #------------------------------------------
    #++
    ## convert to Json
    def toJson()
      json = super() ;
      json[:type] = 'relation' ;
      json[:zone] = @tag[Tag_SavsZone] ;
      lonlat = @memberList[0][:obj].getLonLat() ;
      json[:lonlat] = lonlat ;
      
      return json ;
    end

  end # class OsmMap::Relation
  
  #--============================================================
  #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  #--------------------------------------------------------------
end # class OsmMap

########################################################################
########################################################################
########################################################################
if($0 == __FILE__) then

  require 'test/unit'

  #--============================================================
  #++
  ## unit test for this file.
  class TC_Foo < Test::Unit::TestCase
    #--::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## desc. for TestData
    TestData = nil ;

    #----------------------------------------------------
    #++
    ## show separator and title of the test.
    def setup
#      puts ('*' * 5) + ' ' + [:run, name].inspect + ' ' + ('*' * 5) ;
      name = "#{(@method_name||@__name__)}(#{self.class.name})" ;
      puts ('*' * 5) + ' ' + [:run, name].inspect + ' ' + ('*' * 5) ;
      super
    end

    #----------------------------------------------------
    #++
    ## about test_a
    def test_a
      pp [:test_a] ;
      assert_equal("foo-",:foo.to_s) ;
    end

  end # class TC_Foo < Test::Unit::TestCase
end # if($0 == __FILE__)
