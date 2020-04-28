#! /usr/bin/env ruby
## -*- mode: ruby -*-
## = SAV Simulator
## Author:: Anonymous3
## Version:: 0.0 2018/01/23 Anonymous3
##
## === History
## * [2018/01/23]: Create This File.
## * [YYYY/MM/DD]: add more
## == Usage
## * ...

def $LOAD_PATH.addIfNeed(path)
  self.unshift(path) if(!self.include?(path)) ;
end

$LOAD_PATH.addIfNeed("~/lib/ruby");
$LOAD_PATH.addIfNeed(File.dirname(__FILE__));
$LOAD_PATH.addIfNeed(File.dirname(__FILE__) + "/../Traci");

require 'pp' ;

require 'SumoManager.rb' ;
require 'SavVehicle.rb' ;

#--======================================================================
#++
## Sav module
module Sav

  #--============================================================
  #++
  ## class for SavBase
  class SavBase
    
    #--::::::::::::::::::::::::::::::::::::::::
    #++
    ## default prefix for name of SavBase.
    DefaultSavBaseNamePrefix = "SavBase_" ;
    ## default color of the base.
    DefaultColor = "IndianRed" ;
    ## default color alpha of the base.
    DefaultColorAlpha = 200 ;
    
    ## SavBase counter
    @@counter = 0 ;
    
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## link to SavSimulator
    attr_accessor :simulator ;
    ## name
    attr_accessor :name ;
    ## position
    attr_accessor :position ;
    ## edge
    attr_accessor :edge ;
    ## initial route name
    attr_accessor :routeId ;
    ## poi
    attr_accessor :poi ;

    ## sav Vehicle list ;
    attr_accessor :savList ;
    ## sav Vehicle table ;
    attr_accessor :savTable ;
    
    #------------------------------------------
    #++
    ## initialize
    ## _savSim_ :: parent simulator
    ## _position_ :: position of the base
    ## _name_:: the name of the base. Should be unique.
    ## _addPoiP_:: if true, add the location as PoI on the map.
    def initialize(savSim, position, name = nil, addPoiP = true)
      @simulator = savSim ;
      @position = position ;

      # use default name if name is nil.
      @name = name || ("#{DefaultSavBaseNamePrefix}%05d" % @@counter) ;

      @edge = @simulator.map.findNearestEdgeFrom(@position) ;

      @routeId = @name ;
      @simulator.vehicleManager.submitNewRoute(@routeId, [@edge.id]) ;

      addAsPoi() if(addPoiP) ;

      @savList = [] ;
      @savTable = {} ;

      @@counter += 1 ;
    end

    #------------------------------------------
    #++
    ## add as PoI
    ## _color_:: color of PoI
    def addAsPoi(color = DefaultColor)
      @poi = @simulator.poiManager.submitNewPoi(@position, @name) ;
      @poi.submitColor(color, DefaultColorAlpha) ;
    end
    
    #------------------------------------------
    #++
    ## add savVehicle
    def getSpan()
      @poi.span;
    end
    
    #------------------------------------------
    #++
    ## add savVehicle
    def addNewSavVehicle() ;
      newSav =
        @simulator.vehicleManager.submitNewVehicle({ :base => self },
                                                   @simulator.vehicleType,
                                                   @routeId,
                                                   :triggered) ;
#                                                   @simulator.currentTime) ;
      newSav.submitMoveTo([@edge.id, 0],  getSpan()) ;
      #        newSav.submitStop(@edge.id, getSpan(), 0, 10) ;
      newSav.insertDummyViaPointByPos(@edge.getEndPoint()) ;
      newSav.setNextViaPointAsTarget() ;
      
      @savList.push(newSav) ;
      @savTable[newSav.id] = newSav ;
      return newSav ;
    end
    
    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------

    #--========================================
    #--::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #------------------------------------------

  end # class SavBase
  
end # module Sav

########################################################################
########################################################################
########################################################################
if($0 == __FILE__) then

  require 'test/unit'

  #--============================================================
  #++
  ## unit test for this file.
  class TC_SavBase < Test::Unit::TestCase
    #--::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## desc. for TestData
    SampleDirBase = "/home/noda/work/iss/SAVS/Data" ;
    SampleDir = "#{SampleDirBase}/2018.0104.Tsukuba"
    SampleConfFile03 = "#{SampleDir}/tsukuba.03.sumocfg" ;

    SampleXmlMapFile = "#{SampleDir}/TsukubaCentral.small.net.xml" ;
    SampleJsonMapFile = SampleXmlMapFile.gsub(/.xml$/,".json") ;

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
    end

  end # class TC_Foo < Test::Unit::TestCase
end # if($0 == __FILE__)
