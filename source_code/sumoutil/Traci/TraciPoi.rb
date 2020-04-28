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
    ## PoI class
    class Poi < WithConfParam
      #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      #++
      ## description of DefaultOptsions.
      DefaultConf = { :type => "",
                      :color => 'orange',
                      :colorAlpha => 127,  # alpha value for color.
                      :layer => 0, ## bigger for upper
                      nil => nil } ;

      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #++
      ## id
      attr_accessor :id ;
      ## position
      attr_accessor :pos ;
      ## type
      attr_accessor :type ;
      ## color
      attr_accessor :color ;
      ## colorAlpha
      attr_accessor :colorAlpha ;
      ## layer
      attr_accessor :layer ;
      ## manager
      attr_accessor :manager ;

      #--------------------------------------------------------------
      #++
      ## description of method initialize
      ## _manager_:: PoiManager
      ## _id_:: ID of PoI.
      ## _position_:: position of PoI. a Geo2D::Point or [x, y]
      ## _conf_:: configulation
      def initialize(manager, id, position, conf = {})
        super(conf) ;
        setup(manager, id, position) ;
      end
      
      #--------------------------------------------------------------
      #++
      ## setup configuration
      ## _manager_:: PoiManager
      ## _id_:: ID of PoI.
      ## _position_:: position of PoI. a Geo2D::Point or [x, y]
      def setup(manager, id, position)
        @manager = manager ;
        @id = id ;
        @pos = Geo2D::Point.sureGeoObj(position) ;
        @type = getConf(:type) ;
        @color = getConf(:color) ;
        @colorAlpha = getConf(:colorAlpha) ;
        @layer = getConf(:layer) ;
        self ;
      end

      #--------------------------------------------------------------
      #++
      ## make sure the client
      ## _client_:: TraciClient
      ## *return*:: TraciClient
      def ensureTraciClient(client)
        if(client.nil? && !@manager.nil?) then
          return @manager.traciClient ;
        elsif(client.is_a?(TraciClient)) then
          return client ;
        else
          raise "Illegal client: #{client.inspect} in Vehicle:#{self.inspect}."
        end
      end
        
      #--------------------------------------------------------------
      #++
      ## create Add command
      def traciCom_Add()
        args = { :type => @type,
                 :color => Sumo::Util.getColorValue(@color, @colorAlpha),
                 :layer => @layer,
                 :position => {:x => @pos.x, :y => @pos.y} } ;
        com = Sumo::Traci::Command_SetVariable.new(:poi, :addPoi,
                                                   @id, args) ;
        return com ;
      end

      #--------------------------------------------------------------
      #++
      ## submit Add command
      def submitAdd(client = nil)
        client = ensureTraciClient(client) ;
        com = traciCom_Add() ;
        client.execCommands(com) ;
        com.checkResultCodeIsOk() ;
      end

      #--------------------------------------------------------------
      #++
      ## description of method initialize
      ## _conf_:: configulation
      def traciCom_Remove()
        com = Sumo::Traci::Command_SetVariable.new(:poi, :removePoi,
                                                   @id, @layer) ;
        return com ;
      end

      #--------------------------------------------------------------
      #++
      ## submit Remove command
      def submitRemove(client = nil)
        client = ensureTraciClient(client) ;
        com = traciCom_Remove() ;
        client.execCommands(com) ;
        com.checkResultCodeIsOk() ;
      end

      #--------------------------------------------------------------
      #++
      ## submit change Color
      def submitColor(color, alpha = @colorAlpha, client = nil)
        client = ensureTraciClient(client) ;

        @color = color ;
        @colorAlpha = alpha ;
        colVal = Util.getColorValue(@color, @colorAlpha) ;
        com = Sumo::Traci::Command_SetVariable.new(:poi, :color,
                                                   @id, colVal) ;
        client.execCommands(com) ;
        com.checkResultCodeIsOk() ;
      end

      #--------------------------------
      #++
      ## re-define inspect
      alias inspect_original inspect ;
      def inspect()
        dummy = self.dup ;
        dummy.remove_instance_variable('@manager') if(dummy.manager) ;
        dummy.remove_instance_variable('@conf') if(dummy.conf) ;
        return dummy.inspect_original ;
      end
      
      #--------------------------------------------------------------
      #++
      ## to_s
      def to_s()
        "#<#{self.class}: @id=#{@id}, @pos=#{@pos}>"
      end

    end # class Poi

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
    end
    
  end # class TC_Foo < Test::Unit::TestCase
end # if($0 == __FILE__)
