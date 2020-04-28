#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = Traci PoI (Point of Interest) Manager class
## Author:: Anonymous3
## Version:: 0.0 2018/01/04 Anonymous3
##
## === History
## * [2018/01/14]: Create This File.
## * [YYYY/MM/DD]: add more
## == Usage
## * ...

def $LOAD_PATH.addIfNeed(path)
  self.unshift(path) if(!self.include?(path)) ;
end

$LOAD_PATH.addIfNeed("~/lib/ruby");
$LOAD_PATH.addIfNeed(File.dirname(__FILE__));

require 'Geo2D.rb' ;

require 'TraciUtil.rb' ;
require 'TraciClient.rb' ;
require 'TraciPoi.rb' ;
require 'TraciGroundedPoi.rb' ;

#--===========================================================================
#++
## package for SUMO
module Sumo

  #--======================================================================
  #++
  ## module for Traci
  module Traci

    #--======================================================================
    #++
    ## Traci::PoiManager
    class PoiManager < WithConfParam
      #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      #++
      ## description of DefaultOptsions.
      DefaultConf = { :defaultPoiClass => Poi,
                      :traciClient => nil,
                      :poiIdFormat => "poi_%09d",
                      :poiConf => {},
                      nil => nil } ;

      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #++
      ## poi table { id => poi }
      attr_accessor :poiTable ;
      ## poi list
      attr_accessor :poiList ;
      ## default class of PoI instance
      attr_accessor :defaultPoiClass ;
      ## traci client
      attr_accessor :traciClient ;
      ## vehicle ID prefix
      attr_accessor :poiIdFormat ;
      ## vehicle counter
      attr_accessor :poiIdCounter ;
      ## default Conf to create new PoI.
      attr_accessor :poiConf ;

      #--------------------------------------------------------------
      #++
      ## description of method initialize
      ## _conf_:: configulation
      def initialize(conf = {})
        super(conf) ;
        setup() ;
      end

      #--------------------------------------------------------------
      #++
      ## setup
      def setup()
        @poiTable = {} ;
        @poiList = [] ;
        @defaultPoiClass = getConf(:defaultPoiClass) ;
        @poiIdFormat = getConf(:poiIdFormat) ;
        @poiIdCounter = 0 ;
        @poiConf = getConf(:poiConf) ;
        setTraciClient(getConf(:traciClient)) ;
      end

      #--------------------------------------------------------------
      #++
      ## generate novel vehicle ID
      def novelPoiId()
        begin
          newId = @poiIdFormat % @poiIdCounter ;
          @poiIdCounter += 1 ;
        end while(@poiTable[newId]) ;
        return newId ;
      end

      #--------------------------------------------------------------
      #++
      ## set traci client
      ## _client_:: instance of TraciClient or nil
      def setTraciClient(client)
        @traciClient = client ;
      end

      #--------------------------------------------------------------
      #++
      ## submit new PoI
      ## _position_ :: XY position (in Geo2D::Point or [x, y])
      ## _poiId_ :: poiId. if nil assign novel one.
      ## _conf_ :: config for new PoI
      ## *return* :: new PoI
      def submitNewPoi(position, poiId = nil, conf = {})
        poiId = poiId || novelPoiId() ;
        _poiConf = @poiConf.dup.update(conf) ;
        
        newPoi = @defaultPoiClass.new(self, poiId, position, _poiConf) ;
        submitAddPoi(newPoi) ;
      end

      #--------------------------------------------------------------
      #++
      ## submit add PoI
      ## _poi_ :: poi to add
      ## *return* :: new PoI
      def submitAddPoi(poi)
        poi.submitAdd() ;

        @poiTable[poi.id] = poi ;
        @poiList.push(poi) ;
        
        return poi ;
      end

      #--------------------------------------------------------------
      #++
      ## submit new PoI
      ## _poi_ :: PoI instance or PoI ID.
      ## *return* :: removed object.
      def submitRemovePoi(poi)
        poiObj = (poi.is_a?(Poi) ? poi : @traciTable[poi]) ;

        raise "unknown Poi id : #{poi}" if(poiObj.nil?) ;

        poiObj.submitRemove() ;

        @poiTable.delete(poiObj.id) ;
        @poiList.delete(poiObj) ;

        return poiObj ;
      end

      #--------------------------------------------------------------
      #++
      ## number of PoI
      def nPoi()
        return @poiList.size() ;
      end
      
      #--============================================================
      #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #--------------------------------------------------------------
    end # class PoiManager

  end # module Traci

end # module Sumo

########################################################################
########################################################################
########################################################################
if($0 == __FILE__) then

  require 'test/unit'

  #--============================================================
  #++
  ## unit test for this file.
  class TC_VehicleManager < Test::Unit::TestCase
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

    #--::::::::::::::::::::::::::::::::::::::::::::::::::
    SampleDir = "#{Sumo::SumoSrcBase}/docs/examples/sumo"
    SampleConfFile = "#{SampleDir}/hokkaido/hokkaido.sumocfg" ;
    
    SampleDir2 = "/home/noda/work/iss/SAVS/Data" ;
    SampleConfFile2 = "#{SampleDir2}/2018.0104.Tsukuba/tsukuba.01.sumocfg" ;
    SampleConfFile2b = "#{SampleDir2}/2018.0104.Tsukuba/tsukuba.02.sumocfg" ;

    #----------------------------------------------------
    #++
    ## run with manager using simple map
    def test_a
      traci =
        Sumo::Traci::Client.newWithServer(SampleConfFile2b,
                                          { :logDev => [:stdout,:file],
#                                            :logLevel => :debug,
#                                            :logLevel => :info,
                                            :logLevel => :warn,
                                          },
                                          :gui) ;
      #
      managerConf = { :traciClient => traci,
                      nil => nil }
      pManager = Sumo::Traci::PoiManager.new(managerConf) ;

      # loop
      c = 0 ;
      step = 0 ;
#      ustep = 100 ;
      ustep = 1000 ;
#      delay = 0.001 ;
      delay = 0.000 ;

      while(step < 10000*1000)
        traci.fetchSimulationTime() ;
        # simulation を進める。
        c += 1;
        step += ustep
        com = Sumo::Traci::Command_SimulationStep.new(step) ;
        traci.execCommands(com) ;

        if(c % 100 == 0) then
          pManager.submitNewPoi([1500 + rand() * 2000.0,
                                 3500 + rand() * 2000.0]) ;
          if(pManager.nPoi() > 10) then
            poi = pManager.poiList.first() ;
            pManager.submitRemovePoi(poi) ;
            poi2 = pManager.poiList.sample();
            poi2.submitColor(['RoyalBlue','pink', 'SeaGreen'].sample()) ;
          end
        end
        #sleep
        sleep(delay) ;

      end
      traci.closeServer() ;
    end
    
  end # class TC_Foo < Test::Unit::TestCase
end # if($0 == __FILE__)
