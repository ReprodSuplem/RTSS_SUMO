#! /usr/bin/env ruby
## -*- mode: ruby -*-
## = DuaRouter Wrapper
## Author:: Anonymous3
## Version:: 0.0 2018/01/05 Anonymous3
##
## === History
## * [2018/01/05]: Create This File.
## * [YYYY/MM/DD]: add more
## == Usage
## * ...

require 'optparse' ;
require 'pp' ;

def $LOAD_PATH.addIfNeed(path)
  self.upshift(path) if(!self.include?(path)) ;
end

$LOAD_PATH.addIfNeed("~/lib/ruby");
$LOAD_PATH.addIfNeed(File.dirname(__FILE__));

require 'ItkXml.rb' ;

require 'WithConfParam.rb' ;

#--===========================================================================
#++
## package for SUMO
module Sumo
  #--======================================================================
  #++
  ## DuaRouter Wrapper
  class DuaRouter < WithConfParam
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## description of DefaultValues.
    DuaRouterCommand = "duarouter" ;
    ## default config
    DefaultConf = { :netFile => nil,
                    :cleanUp => true,
                    :nil => nil } ;
    ## working dir
    WorkingDir = "/tmp" ;
    ## working files
    WorkingTripFileNameFormat = "#{WorkingDir}/SumoDuaRouter_%d_%d.trip.xml" ;
    WorkingRouteFileNameFormat = "#{WorkingDir}/SumoDuaRouter_%d_%d.route.xml" ;
    WorkingRouteAltFileNameFormat = "#{WorkingDir}/SumoDuaRouter_%d_%d.route.alt.xml" ;

    #--============================================================
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## execution counter
    @@execCount = 0 ;

    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## map network file.
    attr_accessor :netFile ;

    ## input trip file
    attr_accessor :tripFile ;

    ## output route file
    attr_accessor :routeFile ;
    
    ## alt output route file
    attr_accessor :routeAltFile ;

    ## trip id index
    attr_accessor :tripId ;
    
    ## table of trip
    attr_accessor :tripTable ;
    
    ## table of route
    attr_accessor :routeTable ;
    
    ## table of route
    attr_accessor :cleanUp ;
    
    #--------------------------------------------------------------
    #++
    ## initializer
    ## _conf_:: config
    def initialize(conf)
      super(conf) ;
      setupFiles() ;
      @tripId = 0 ;
      @cleanUp = getConf(:cleanUp) ;
    end

    #--------------------------------------------------------------
    #++
    ## setup files.
    def setupFiles()
      @netFile = getConf(:netFile) ;
      count = @@execCount ;
      @@execCount += 1; ;
      @tripFile = WorkingTripFileNameFormat % [$$, count] ;
      @routeFile = WorkingRouteFileNameFormat % [$$, count] ;
      @routeAltFile = WorkingRouteAltFileNameFormat % [$$, count] ;
    end
    
    #--------------------------------------------------------------
    #++
    ## generate trip element
    ## _id_:: about argument bar
    ## _trip_ :: list of visit point (Array of String)
    ## *return*:: generated trip element
    def generateTripElement(id, trip)
      from = nil ;
      to = nil ;
      via = [] ;
      trip.each{|edge|
        if(from.nil?) then
          from = edge ;
        else
          via.push(edge) ;
        end
      }
      to = via.pop() ;
      
      tripXmlHead = [nil, 'trip',
                     ['id', id],
                     ['from', from],
                     ['to', to],
                     ['depart', "0"]] ;
      if(via.length > 0) then
        viaString = via.join(' ') ;
        tripXmlHead.push(['via', viaString]) ;
      end
      
      return [tripXmlHead] ;
    end

    #--------------------------------------------------------------
    #++
    ## generate trip XML Array
    ## _tripTable_ :: a Hash Table of id and list of visit point
    ## *return*:: generated xml array
    def generateTripXmlArray(tripTable = @tripTable)
      @tripTable = tripTable ;
      
      xml = ['routes'] ;
      tripTable.each{|id, trip|
        element = generateTripElement(id, trip) ;
        xml.push(element) ;
      }
      return xml ;
    end

    #--------------------------------------------------------------
    #++
    ## generate trip XML Array
    ## _tripTable_ :: a Hash Table of id and list of visit point
    ## *return*:: generated xml array
    def outputTripFile(tripTable)
      xmlForm = generateTripXmlArray(tripTable);
      xml = ItkXml::to_Xml(xmlForm) ;
      open(@tripFile,"w"){|strm|
        ItkXml::ppp(xml, strm) ;
      }
    end

    #--------------------------------------------------------------
    #++
    ## call duarouter.
    def callDuaRouter()
      com = "#{DuaRouterCommand} -n #{@netFile}" ;
      com += " -t #{@tripFile} -o #{@routeFile}" ;
      system(com) ;
    end

    #--------------------------------------------------------------
    #++
    ## call duarouter.
    def scanRouteFile()
      @routeTable = {} ;
      open(@routeFile,"r"){|strm|
        xml = XML::Document.new(strm) ;
        XML::XPath.each(xml, "//vehicle"){|vXml|
          id = vXml.attribute('id').to_s ;
          routeString = vXml.get_elements("route")[0].attribute('edges').to_s ;
          route = routeString.split(' ') ;
          @routeTable[id] = route ;
        }
      }
      return @routeTable ;
    end

    #--------------------------------------------------------------
    #++
    ## top level
    def getRouteTableFromTripTable(tripTable)
      outputTripFile(tripTable) ;
      callDuaRouter() ;
      scanRouteFile() ;

      cleanUpWorkingFiles() if(@cleanUp) ;

      return @routeTable ;
    end

    #--------------------------------------------------------------
    #++
    ## clean up working file
    def cleanUpWorkingFiles()
      system("rm -f #{@tripFile} #{routeFile} #{routeAltFile}") ;
    end

    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------
  end # class DuaRouter < WithConfParam
end # module Sumo
  

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
    NetFile = "/home/noda/work/iss/SAVS/Data/2018.0104.Tsukuba/TsukubaCentral.small.net.xml" ;

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
      router = Sumo::DuaRouter.new({ :netFile => NetFile,
                                     :cleanUp => true,
                                   }) ;

      tripTable = { '0' => ['200342832#0', '-130218262', '342962487#18'],
                    '1' => ['473595249#0', '200342836#10'] } ;

      r = router.getRouteTableFromTripTable(tripTable) ;
      p [:r, r] ;
    end

  end # class TC_Foo < Test::Unit::TestCase
end # if($0 == __FILE__)
