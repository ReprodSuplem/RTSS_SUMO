#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = SAV Random Demand Factory
## Author:: Anonymous3
## Version:: 0.0 2018/01/28 Anonymous3
##
## === History
## * [2018/01/28]: Create This File.
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

require 'SavDemandFactory.rb' ;

#--======================================================================
#++
## Sav module
module Sav

  #--============================================================
  #++
  ## class for Factory of SavDemand
  class SavDemandFactoryRandom < SavDemandFactory
    
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## description of DefaultOptsions.
    DefaultConf = {
#      :mode => :center, # if :center, make a box 
      :center => :midPoint,  # :midPoint or Geo2D::Point
      :offset => Geo2D::Point.new(0.0, 0.0),
      :rangeSize => 1000.0,  # float or Geo2D::Vector
      :passengerList => ["foo"],
      :frequency => 1.0 / 10.0, # how frequent?
      :minDistance => 0.0,
      :walkSpeed => 3.0 * 1000 / 60 / 60, # 平均歩行速度
#      :walkSpeed => 1.0 * 1000 / 60 / 60, # 平均歩行速度      
    } ;
                    
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## range of demand 
    attr_accessor :rangeBox ;
    ## passenger list
    attr_accessor :passengerList ;
    ## frequency
    attr_accessor :frequency ;
    ## minimum distance of origin-destination
    attr_accessor :minDistance ;
    ## average walk speed
    attr_accessor :walkSpeed ;
    
    #------------------------------------------
    #++
    ## setup.
    def setup()
      super() ;
      setupRangeBox() ;
      setupPassengerList() ;
      @frequency = getConf(:frequency) ;
      @minDistance = getConf(:minDistance) ;
      @walkSpeed = getConf(:walkSpeed) ;
    end
    
    #------------------------------------------
    #++
    ## setup @rangeBox.
    def setupPassengerList() ;
      @passengerList = getConf(:passengerList) ;
      return self ;
    end
    
    #------------------------------------------
    #++
    ## setup @rangeBox.
    def setupRangeBox()
      ## center
      center = getConf(:center) ;
      if(center == :midPoint) then
        center = @simulator.map.bbox().midPoint() ;
        center += getConf(:offset) ;
      end

      ## rangeSize
      rangeSize = getConf(:rangeSize) ;
      if(!rangeSize.is_a?(Geo2D::Vector)) then
        rangeSize = Geo2D::Vector.new(rangeSize, rangeSize) ;
      end

      ##rangeBox
      @rangeBox = center.bbox() ;
      @rangeBox.growBySize(rangeSize) ;

      return self ;
    end
    
    #------------------------------------------
    #++
    ## generate new demand() ;
    def newDemand()
      begin
        pickUpPos = @rangeBox.randomPoint() ;
        dropOffPos = @rangeBox.randomPoint() ;
      end until(pickUpPos.distanceTo(dropOffPos) > @minDistance) ;

      passenger = @passengerList.sample() ;
      numPassenger = 1 ;

      demand = Sav::SavDemand.new(passenger, numPassenger,
                                  Trip.new(pickUpPos, dropOffPos),
                                  @simulator,
                                  @demandConf) ;

      ## 締め切り時刻設定
      aveDist = Sav::Util.averageManhattanDistance(pickUpPos, dropOffPos) ;
      deadLine = @simulator.currentTime + aveDist / @walkSpeed ;
      demand.tripRequiredTime.dropOff = deadLine ;

      return demand ;
    end
    
    #------------------------------------------
    #++
    ## generate new demands in a cycle
    def newDemandListForCycle()
      list = [] ;
      if(rand() < @frequency)
        list.push(newDemand()) ;
      end
      return list ;
    end
    
    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------

  end # class SavDemandFactoryRandom
  
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
