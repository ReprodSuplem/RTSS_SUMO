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
    ## PoI to grounded to edge.
    ## The poi that is grounded on edge.
    ## The position is located the foot point 
    class GroundedPoi < Poi
      #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      #++
      ## description of DefaultOptsions.
      DefaultOriginSuffix = "_Origin" ;
      ## description of DefaultOptsions.
      DefaultConf = { :originColor => 'grey',
                      :originSuffix => DefaultOriginSuffix,
                      :edge => nil,  # edge to ground.
                      :map => nil,   # map to find the nearest edge.
                      nil => nil } ;
      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #++
      ## origin PoI. the poi to indicate original position.
      attr_accessor :origin ;
      ## edge to ground.
      attr_accessor :edge ;
      ## span distance of the foot point on the edge 
      attr_accessor :span ;

      #--------------------------------------------------------------
      #++
      ## description of method initialize
      ## _manager_:: PoiManager
      ## _id_:: ID of PoI.
      ## _position_:: position of PoI. a Geo2D::Point or [x, y]
      ## _conf_:: configulation. must have :edge or :map entry.
      def initialize(manager, id, position, conf = {})
        super(manager, id, position, conf) ;
        setupOrigin(manager, id, position, conf.dup) ;
        setupGround(manager, id, position) ;
      end
      
      #--------------------------------------------------------------
      #++
      ## setup for origin.
      ## _manager_:: PoiManager
      ## _id_:: ID of PoI.
      ## _position_:: position of PoI. a Geo2D::Point or [x, y]
      ## _conf_:: configulation
      def setupOrigin(manager, id, position, conf = {})
        conf[:color] = getConf(:originColor) ;
        originId = id + getConf(:originSuffix) ;
        @origin = Poi.new(manager, originId, position, conf) ;
      end
      
      #--------------------------------------------------------------
      #++
      ## setup for grounded PoI
      ## _manager_:: PoiManager
      ## _id_:: ID of PoI.
      ## _position_:: position of PoI. a Geo2D::Point or [x, y]
      ## _conf_:: configulation (must have :edge or :map entry)
      def setupGround(manager, id, position, conf = {})
        position = Geo2D::Point.sureGeoObj(position) ;

        if(getConf(:edge).nil? && getConf(:map).nil?) then
          raise SumoException.new("GroundedPoi needs :edge or :map. " +
                                  "conf=" + conf.inspect) ;
        end

        @edge = getConf(:edge) || getConf(:map).findNearestEdgeFrom(position) ;
                   
        @pos = @edge.footPointFrom(position) ;
        @span = @edge.footPointSpanFrom(position, true) ;
      end

      #--------------------------------------------------------------
      #++
      ## submit Add command
      def submitAdd(client = nil)
        super(client) ;
        @origin.submitAdd(client) ;
      end
      
      #--------------------------------------------------------------
      #++
      ## submit Remove command
      def submitRemove(client = nil)
        super(client) ;
        @origin.submitRemove(client) ;
      end
      
    end # class GroundedPoi

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
