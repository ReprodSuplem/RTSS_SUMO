#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = Sumo Map Handler
## Author:: Anonymous3
## Version:: 0.0 2018/01/07 Anonymous3
##
## === History
## * [2018/01/07]: Create This File.
## * [YYYY/MM/DD]: add more
## == Usage
## * ...

require 'optparse' ;
require 'pp' ;
require 'json' ;


def $LOAD_PATH.addIfNeed(path)
  self.unshift(path) if(!self.include?(path)) ;
end

$LOAD_PATH.addIfNeed("~/lib/ruby");

require 'Geo2D.rb' ;
require 'RTree.rb' ;
require 'ItkXml.rb' ;

$LOAD_PATH.addIfNeed(File.dirname(__FILE__));

require 'WithConfParam.rb' ;
require 'ExpLogger.rb' ;

require 'TraciUtil.rb' ;

require 'SumoMapCoordSystem.rb' ;
require 'SumoMapJunction.rb' ;
require 'SumoMapLane.rb' ;
require 'SumoMapEdge.rb' ;

#--===========================================================================
#++
## package for SUMO
module Sumo

  #--======================================================================
  #++
  ## description of class Foo.
  class SumoMap < WithConfParam

    #--============================================================
    ## common utility
    #--------------------------------------------------------------
    #++
    ## 
    def self.getAttrVal(xml, attr)
      val = xml.attribute(attr) ;
      return (val.nil? ? nil : val.to_s) ;
    end

    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## description of DefaultOptsions.
    DefaultConf = { :bar => :baz } ;

    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## coordination system
    attr_accessor :coordSystem ;
    ## edge table
    attr_accessor :edgeTable ;
    ## lane table
    attr_accessor :laneTable ;
    ## junction table
    attr_accessor :junctionTable ;
    ## originalIdTable ;
    attr_accessor :originalIdTable ;
    ## edge rtree
    attr_accessor :edgeRTree ;
    ## lane rtree
    attr_accessor :laneRTree ;
    ## junction rtree
    attr_accessor :junctionRTree ;
    ## logger
    attr_accessor :logger ;

    #--------------------------------------------------------------
    #++
    ## initialize
    def initialize(conf = {})
      super(conf) ;
      setup() ;
    end

    #--------------------------------------------------------------
    #++
    ## setup
    def setup()
      @edgeTable = {} ;
      @laneTable = {} ;
      @junctionTable = {} ;
      @originalIdTable = {} ;
    end

    #--------------------------------------------------------------
    #++
    ## load XML file.
    ## _netFile_:: MapNet XML file.
    ## _vehicleType_ :: if non-nil, scan only permitted edge for the type.
    ##           typical value is :private or :taxi or :bus or :delivery
    ## *return*:: 
    def loadXmlFile(netFile, vehicleType = nil, excludeTypeList = [])
      fparser = ItkXml::FilterParser.new(File.new(netFile)) ;

      fparser.listenQName("location") {|xml, str|
        @coordSystem = CoordSystem.new(xml) ;
      }
      
      fparser.listenQName("edge", {'type' => //}){|xml, str|
        edge = Edge.new(xml) ;
        #non-permitted type is not scanned.
        if((vehicleType.nil? ||edge.checkPermissionFor(vehicleType)) &&
           (!edge.shouldBeExcluded(excludeTypeList))) then
          @edgeTable[edge.id] = edge ;
        end
      }
      
      fparser.listenQName("junction") {|xml, str|
        junction = Junction.new(xml) ;
        @junctionTable[junction.id] = junction ;
      }
      
      fparser.parse ;

      disposeMapComponents() ;
      
      return self ;
    end

    #--------------------------------------------------------------
    #++
    ## dispose and reallange parts of the network.
    ## *return*:: self
    def disposeMapComponents()
      @edgeTable.each{|id, edge|
        ## construct lane table
        edge.laneList.each{|lane|
          @laneTable[lane.id] = lane ;
        }

        ## registr originalId table
        if(@originalIdTable[edge.originalId].nil?) then
          @originalIdTable[edge.originalId] = [] ;
        end
        @originalIdTable[edge.originalId].push(edge) ;

        ## link junctions
        junctionFrom = @junctionTable[edge.fromId] ;
        junctionTo = @junctionTable[edge.toId] ;
        edge.from = junctionFrom ;
        edge.to = junctionTo ;
        junctionFrom.edgeIdListOut.push(edge.id) ;
        junctionTo.edgeIdListIn.push(edge.id) ;
      }
      return self ;
    end
      
    #--------------------------------------------------------------
    #++
    ## build rtree
    ## *return*:: self
    def buildRTrees()
      logging(:info, "building Rtrees.") ;
      ## edge
      nEdge = @edgeTable.size() ;
      cEdge = 0 ;
      logging(:info, "building edge RTree: total=" + nEdge.to_s) ;
      @edgeRTree = Geo2D::RTree.new() ;
      @edgeTable.values.shuffle.each{|edge|
        @edgeRTree.insert(edge) ;
        cEdge += 1 ;
        logging(:info, "insert edges:" + cEdge.to_s) if(cEdge % 2000 == 0) ;
      }

      ## lane
      nLane = @laneTable.size() ;
      cLane = 0 ;
      logging(:info, "building lane RTree: total=" + nLane.to_s) ;
      @laneRTree = Geo2D::RTree.new() ;
      @laneTable.values.shuffle.each{|lane|
        @laneRTree.insert(lane) ;
        cLane += 1 ;
        logging(:info, "insert lanes:" + cLane.to_s) if(cLane % 2000 == 0) ;
      }
      
      ## junction
      nJunc = @junctionTable.size() ;
      cJunc = 0 ;
      logging(:info, "building junction RTree: total=" + nJunc.to_s) ;
      @junctionRTree = Geo2D::RTree.new() ;
      @junctionTable.values.shuffle.each{|junction|
        @junctionRTree.insert(junction) ;
        cJunc += 1 ;
        logging(:info, "insert junctions:" + cJunc.to_s) if(cJunc % 5000 == 0) ;
      }

      return self ;
    end

    #--------------------------------------------------------------
    #++
    ## convert to JSON object (hash)
    def toJson()
      json = { 'class' => self.class.to_s } ;

      ## coord system
      json['location'] = @coordSystem.toJson() ;

      ## edge list
      _edgeList = [] ;
      @edgeTable.each{|id, edge|
        _edgeList.push(edge.toJson()) ;
      }
      json['edgeList'] = _edgeList ;

      ## junction list
      _junctionList = [] ;
      @junctionTable.each{|id, junction|
        _junctionList.push(junction.toJson()) ;
      }
      json['junctionList'] = _junctionList ;

      return json ;
    end

    #--------------------------------------------------------------
    #++
    ## save to Json file
    ## _jsonFile_ :: JSON for one Edge.
    def saveJsonFile(jsonFile, prettyP = true)
      json = toJson() ;
      jsonStr = (prettyP ?
                   JSON.pretty_generate(json) :
                   JSON.generate(json)) ;
      open(jsonFile,"w"){|strm|
        strm << jsonStr ;
      }
    end
    
    #--------------------------------------------------------------
    #++
    ## scan JSON object (hash)
    ## _vehicleType_ :: if non-nil, scan only permitted edge for the type.
    ##           typical value is :private or :taxi or :bus or :delivery
    ## _json_ :: JSON for one Edge.
    def scanJson(json, vehicleType = nil)
      ## coord system
      @coordSystem = CoordSystem.new() ;
      @coordSystem.scanJson(json['location']) ;
      
      ## scan edge
      _edgeList = json['edgeList'] ;
      @edgeTable = {} ;
      _edgeList.each{|edgeJson|
        edge = Edge.new() ;
        edge.scanJson(edgeJson) ;
        #non-permitted type is not scanned.
        if(vehicleType.nil? || edge.checkPermissionFor(vehicleType)) then
          @edgeTable[edge.id] = edge ;
        end
      }

      ## scan junction
      _junctionList = json['junctionList'] ;
      @junctionTable = {} ;
      _junctionList.each{|junctionJson|
        junction = Junction.new() ;
        junction.scanJson(junctionJson) ;
        @junctionTable[junction.id] = junction ;
      }
      
      disposeMapComponents() ;
      
      return self ;
    end

    #--------------------------------------------------------------
    #++
    ## load Json file
    ## _jsonFile_ :: JSON for one Edge.
    ## _vehicleType_ :: if non-nil, scan only permitted edge for the type.
    ##           typical value is :private or :taxi or :bus or :delivery
    def loadJsonFile(jsonFile, vehicleType = nil)
      open(jsonFile,'r'){|strm|
        logging(:info, "loading map file (json):" + jsonFile) ;
        json = JSON.load(strm) ;
        logging(:info, "scan json map") ;
        scanJson(json, vehicleType) ;
      }
      return self ;
    end
    
    #--------------------------------------------------------------
    ## Dump and Restore by Marshal
    #--------------------------------
    #++
    ## dump SumoMap to a file.
    ## _file_:: dump file name.
    def dumpToFile(file)
      open(file,"w"){|strm|
        Marshal::dump(self, strm) ;
      }
    end

    #--==============================
    #--------------------------------
    #++
    ## dump SumoMap to a file. (class method)
    ## _map_:: object to dump
    ## _file_:: dump file name.
    def self.dumpToFile(map, file)
      map.dumpToFile(file) ;
    end
    
    #--==============================
    #--------------------------------
    #++
    ## restore SumoMap from a file. (class method)
    ## _file_:: dump file name.
    ## *return*:: a SumoMap
    def self.restoreFromFile(file)
      open(file,"r"){|strm|
        map = Marshal::restore(strm) ;
        if(!map.is_a?(self)) then
          raise "not a SumoMap dump file:" + file ;
        end
        return map ;
      }
    end

    #--------------------------------------------------------------
    ## transform
    #--------------------------------
    #++
    ## transpormation of coordinate system from LonLat to X-Y
    ## _lonlat_ :: longitude and latitude in Geo2D::Point object
    ## *return_ :: X-Y position in Geo2D::Point object
    def transformLonLat2XY(lonlat)
      return @coordSystem.transformLonLat2XY(lonlat)
    end

    #--------------------------------
    #++
    ## transpormation of coordinate system from X-Y to LonLat 
    ## _xyPos_ :: X-Y position in Geo2D::Point object
    ## *return_ :: Lon-Lat position in Geo2D::Point object
    def transformXY2LonLat(xyPos)
      return @coordSystem.transformXY2LonLat(xyPos)
    end

    #--------------------------------
    #++
    ## find nearest edge from a reference geo object
    ## _reference_ :: Geo2D objects (Point, LineString, Box, ...)
    ## *return_ :: an edge
    def findNearestEdgeFrom(reference)
      @edgeRTree.findNearestFrom(reference) ;
    end

    #--------------------------------
    #++
    ## find nearest lane from a reference geo object
    ## _reference_ :: Geo2D objects (Point, LineString, Box, ...)
    ## *return_ :: a lane
    def findNearestLaneFrom(reference)
      @laneRTree.findNearestFrom(reference) ;
    end
    
    #--------------------------------
    #++
    ## find nearest junction from a reference geo object
    ## _reference_ :: Geo2D objects (Point, LineString, Box, ...)
    ## *return_ :: a junction
    def findNearestJunctionFrom(reference)
      @junctionRTree.findNearestFrom(reference) ;
    end

    #--------------------------------
    #++
    ## find nearest edge from a reference geo object
    ## _reference_ :: lon-lat by Geo2D::Point.
    ## *return_ :: an edge
    def findNearestEdgeFromLonLat(reference)
      ref = transformLonLat2XY(reference)
      p [reference, ref] ;
      findNearestEdgeFrom(ref) ;
    end
    
    #--------------------------------
    #++
    ## find nearest lane from a reference geo object
    ## _reference_ :: lon-lat by Geo2D::Point.
    ## *return_ :: a lane
    def findNearestLaneFromLonLat(reference)
      ref = transformLonLat2XY(reference)
      findNearestLaneFrom(ref)
    end
    
    #--------------------------------
    #++
    ## find nearest junction from a reference geo object
    ## _reference_ :: lon-lat by Geo2D::Point.
    ## *return_ :: a junction
    def findNearestJunctionFromLonLat(reference)
      ref = transformLonLat2XY(reference)
      findNearestJunctionFrom(ref) ;
    end
    
    #--------------------------------
    #++
    ## find nearest edge from a reference geo object
    ## _reference_ :: Geo2D objects (Point, LineString, Box, ...)
    ## *return_ :: [edge, spanOnEdge, footPoint, distance]
    def findNearestOnEdgeFrom(reference)
      edge = findNearestEdgeFrom(reference) ;
      span = edge.footPointSpanFrom(reference) ;
      foot = edge.footPointFrom(reference) ;
      dist = edge.shape.distanceFrom(reference) ;

      return [edge, span, foot, dist] ;
    end
    
    #--------------------------------
    #++
    ## find nearest edge from a reference geo object
    ## _reference_ :: Geo2D objects (Point, LineString, Box, ...)
    ## *return_ :: [edge, spanOnEdge, footPoint, distance]
    def findNearestOnLaneFrom(reference)
      lane = findNearestLaneFrom(reference) ;
      span = lane.footPointSpanFrom(reference) ;
      foot = lane.footPointFrom(reference) ;
      dist = lane.shape.distanceFrom(reference) ;

      return [lane, span, foot, dist] ;
    end
    
    #--------------------------------
    #++
    ## find nearest edge from a reference geo object
    ## _reference_ :: Geo2D objects (Point, LineString, Box, ...)
    ## *return_ :: [edge, spanOnEdge, footPoint, distance]
    def findNearestOnEdgeFromLonLat(reference)
      ref = transformLonLat2XY(reference)
      edge = findNearestEdgeFrom(ref) ;
      span = edge.footPointSpanFrom(ref)
      foot = edge.footPointFrom(ref) ;
      dist = edge.shape.distanceFrom(ref) ;

      return [edge, span, foot, dist] ;
    end
    
    #--------------------------------
    #++
    ## find nearest edge from a reference geo object
    ## _reference_ :: Geo2D objects (Point, LineString, Box, ...)
    ## *return_ :: [edge, spanOnEdge, footPoint, distance]
    def findNearestOnLaneFromLonLat(reference)
      ref = transformLonLat2XY(reference) ;
      lane = findNearestLaneFrom(ref) ;
      span = lane.footPointSpanFrom(ref) ;
      foot = lane.footPointFrom(ref) ;
      dist = lane.shape.distanceFrom(ref) ;

      return [lane, span, foot, dist] ;
    end
    
    #----------------------------------------------------
    #++
    ## get bbox value of the map.
    ## *return_ :: Box instance
    def bbox()
      return @coordSystem.bboxXY() ;
    end
    
    #--------------------------------------------------------------
    #++
    ## set logger
    def setLogger(_logger = nil)
      if(_logger.nil?) then
        @logger = Itk::ExpLogger.new() ;
      else
        @logger = _logger ;
      end
    end

    #--------------------------------
    #++
    ## logging
    def logging(level, *messageList, &body)
      if(!@logger.nil?) then
        @logger.logging(level, *messageList, &body) ;
      else
        STDERR << level << messageList ;
      end
    end
    
    #--------------------------------
    #++
    ## re-define inspect
    alias inspect_original inspect ;
    def inspect()
      dummy = self.class.new() ;
      dummy.coordSystem = self.coordSystem ;
      return dummy.inspect_original ;
    end
    
    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------
    
  end # class SumoMap

end # module Sumo
  
########################################################################
########################################################################
########################################################################
if($0 == __FILE__) then

  require 'test/unit'
  require 'TimeDuration.rb' ;

  #--============================================================
  #++
  ## unit test for this file.
  class TC_Foo < Test::Unit::TestCase
    #--::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## desc. for TestData
    SampleNetFile = "/home/noda/work/iss/SAVS/Data/2018.0104.Tsukuba/TsukubaCentral.small.net.xml" ;

    SampleJsonFile = '/tmp/SumoMap.tmp.json' ;
    SampleJsonFile2 = '/tmp/SumoMap.tmp2.json' ;

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
    ## scan XML file
    def test_a
      td =
        (TimeDuration.new(){
           map = Sumo::SumoMap.new() ;
           map.loadXmlFile(SampleNetFile) ;
           p [:mapLength, map.edgeTable.size, map.laneTable.size,
              map.originalIdTable.size, map.junctionTable.size] ;
         }) ;
      pp td.to_s ;
    end

    #----------------------------------------------------
    #++
    ## scan XML file and save JSON file
    def test_b
      map = Sumo::SumoMap.new() ;
      map.loadXmlFile(SampleNetFile, :private) ;
      p [:mapLength, map.edgeTable.size, map.laneTable.size,
         map.originalIdTable.size, map.junctionTable.size] ;
      map.saveJsonFile(SampleJsonFile) ;
    end

    #----------------------------------------------------
    #++
    ## scan JSON file
    def test_c
      td = 
        (TimeDuration.new(){
           map = Sumo::SumoMap.new() ;
           map.loadJsonFile(SampleJsonFile, :private) ;
           p [:mapLength, map.edgeTable.size, map.laneTable.size,
              map.originalIdTable.size, map.junctionTable.size] ;
         }) ;
      pp td.to_s ;
    end
    
    #----------------------------------------------------
    #++
    ## compare reloaded file.
    def test_d
      map = Sumo::SumoMap.new() ;
      map.loadJsonFile(SampleJsonFile, :private) ;
      p [:mapLength, map.edgeTable.size, map.laneTable.size,
         map.originalIdTable.size, map.junctionTable.size] ;
      map.saveJsonFile(SampleJsonFile2) ;

      map2 = Sumo::SumoMap.new() ;
      map2.loadJsonFile(SampleJsonFile2) ;
      
      p [:mapLength, map2.edgeTable.size, map2.laneTable.size,
         map2.originalIdTable.size, map2.junctionTable.size] ;
    end

    #----------------------------------------------------
    #++
    ## transform test
    def test_e
      map = Sumo::SumoMap.new() ;
      map.loadJsonFile(SampleJsonFile) ;
      lonlat0 = [140.086504, 36.041443] ;
      lonlat1 = [140.155909, 36.121957] ;
      lonlat2 = [140.1216854, 36.0716164] ;
      xyPos_2 = [3164.54, 3330.54] ## lonlat2 の答え。
      xyPos0 = map.transformLonLat2XY(lonlat0) ;
      xyPos1 = map.transformLonLat2XY(lonlat1) ;
      xyPos2 = map.transformLonLat2XY(lonlat2) ;
      lonlat_0 = map.transformXY2LonLat(xyPos0) ;
      lonlat_1 = map.transformXY2LonLat(xyPos1) ;
      lonlat_2 = map.transformXY2LonLat(xyPos2) ;

      p [:lonlat0, lonlat0, xyPos0, lonlat_0] ;
      p [:lonlat1, lonlat1, xyPos1, lonlat_1] ;
      p [:lonlat2, lonlat2, lonlat_2] ;
      p [:xyPos2, xyPos2, xyPos_2] ;
    end

    #----------------------------------------------------
    #++
    ## rtree test
    def test_f
      map = Sumo::SumoMap.new() ;
      td = 
        (TimeDuration.new(){
           map.loadJsonFile(SampleJsonFile) ;
         }) ;
      pp [:loadJsonFile, td.to_s] ;
      
      td = 
        (TimeDuration.new(){
           map.buildRTrees() ;
         }) ;
      pp [:buildRTrees, td.to_s] ;
      
#      map.edgeRTree.showTree()
      p [:edge, :overlap, map.edgeRTree.calcOverlapArea(),
         map.edgeRTree.calcOverlapRatio()] ;
      p [:lane, :overlap, map.laneRTree.calcOverlapArea(),
         map.laneRTree.calcOverlapRatio()] ;
      p [:junction, :overlap, map.junctionRTree.calcOverlapArea(),
         map.junctionRTree.calcOverlapRatio()] ;

      ref = Geo2D::Point.new(0,0)
      (edge, edgeSpan, edgeFoot, edgeDist) = map.findNearestOnEdgeFrom(ref) ;
      (lane, laneSpan, laneFoot, laneDist) = map.findNearestOnLaneFrom(ref) ;
      junc = map.findNearestJunctionFrom(ref) ;
      pp [:nearest, ref,
          [:edge, edge.id, edgeSpan, edge.length, edgeDist],
          [:lane, lane.id, laneSpan, lane.length, laneDist],
          [:junc, junc.id]] ;

      ref = Geo2D::Point.new(3000,4000) ;
      (edge, edgeSpan, edgeFoot, edgeDist) = map.findNearestOnEdgeFrom(ref) ;
      (lane, laneSpan, laneFoot, laneDist) = map.findNearestOnLaneFrom(ref) ;
      junc = map.findNearestJunctionFrom(ref) ;
      pp [:nearest, ref,
          [:edge, edge.id, edgeSpan, edge.length, edgeDist],
          [:lane, lane.id, laneSpan, lane.length, laneDist],
          [:junc, junc.id]] ;

      ref = Geo2D::Point.new(140.15,36.042) ;
      (edge, edgeSpan, edgeFoot, edgeDist) =
        map.findNearestOnEdgeFromLonLat(ref) ;
      (lane, laneSpan, laneFoot, laneDist) =
        map.findNearestOnLaneFromLonLat(ref) ;
      junc = map.findNearestJunctionFromLonLat(ref) ;
      pp [:nearest, :ll, ref,
          [:edge, edge.id, edgeSpan, edge.length, edgeDist],
          edgeFoot,
          [:lane, lane.id, laneSpan, lane.length, laneDist],
          [:junc, junc.id]] ;
    end

  end # class TC_Foo < Test::Unit::TestCase
end # if($0 == __FILE__)
