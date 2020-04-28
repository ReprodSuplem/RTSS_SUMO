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

require 'SavDemandFactoryRandom.rb' ;

#--======================================================================
#++
## Sav module
module Sav

  #--============================================================
  #++
  ## class for Factory of SavDemand.
  ## The config (demandConfig) param should be in the following format:
  ##   <Config> ::= {
  ##                  :from => <Area>,
  ##                  :to   => <Area>,
  ##                  :since => <Time>,
  ##                  :until => <Time>,
  ##                }
  ##   <Area> ::= { :type => "circle",
  ##                :center => <Point>,
  ##                :radius => <Float> }
  ##           || { :type => "polygon",
  ##                :shape => <Polygon> }
  ##           || { :type => "list",
  ##                :list => [<Area>, <Area>, ...] }
  ##   <Point> ::= [ longitude, latitude ]
  ##            || name_of_PoI
  ##   <Polygon> ::= [ <Point>, <Point>, ... ]
  ##              || name_of_zone
  ##   <Time> ::= sec_in_simulation
  class SavDemandFactoryDirected < SavDemandFactoryRandom

    #--============================================================
    ## register the class as a components of the Mixture.
    SavDemandFactoryMixture.registerFactoryType("directed", self) ;

    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## description of DefaultOptsions.
    DefaultConf = {
      :config => {},
      nil => nil
    } ;
                    
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## demandConfig.
    attr_accessor :demandConfig ;
    ## feature table
    attr_accessor :featureTable ;
    ## shape of origin area
    attr_accessor :originAreaShape ;
    ## shape of destination area
    attr_accessor :destinationAreaShape ;
    ## duration to generate
    attr_accessor :sinceTime ;
    ## duration to generate
    attr_accessor :untilTime ;
    
    #------------------------------------------
    #++
    ## setup.
    def setup()
      @featureTable = @simulator.featureTable ;
      @demandConfig = getConf(:config) ;
      super() ;
      @frequency = 1.0 / @demandConfig[:interval] ;
    end
    
    #------------------------------------------
    #++
    ## setup @rangeBox.
    def setupRangeBox()
      @originAreaShape = formAreaShape(@demandConfig[:from]) ;
      @destinationAreaShape = formAreaShape(@demandConfig[:to]) ;
      @sinceTime = @demandConfig[:since] ;
      @untilTime = @demandConfig[:until] ;

      return self ;
    end

    #------------------------------------------
    #++
    ## form area shape from area definition.   
    def formAreaShape(areaDef)
      area = nil ;
      type = areaDef[:type] ;
      case(type)
      when "circle" ;
        centerName = areaDef[:center] ;
        center = getGeoFeature(centerName) ;
        radius = areaDef[:radius] ;
        area = Sav::GeoFeature::Circle.new(center, radius) ;
      when "zone" ;
        zoneName = areaDef[:zone] ;
        area = getGeoFeature(zoneName) ;
      when "list" ;
        list = [] ;
        areaDef[:list].each{|subAreaDef|
          subArea = formAreaShape(subAreaDef) ;
          list.push(subArea) ;
        }
        _name = areaDef[:name] ;
        area = Sav::GeoFeature::List.new(_name, list) ;
      else
        raise "unknown type for Area:" + type ;
      end
      return area
    end

    #------------------------------------------
    #++
    ## get SavGeoFeature by name
    def getGeoFeature(name)
      feature = @featureTable[name] ;
      raise ("unknown SavGeoFeature:" + name) if(feature.nil?) ;

      return feature ;
    end
    
    #------------------------------------------
    #++
    ## generate new demand() ;
    def newDemand()
      pickUpPos = @originAreaShape.getRandomPoint() ;
      dropOffPos = @destinationAreaShape.getRandomPoint() ;

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
      currentTime = @simulator.currentTime ;
      if((@sinceTime.nil? || currentTime > @sinceTime) &&
         (@untilTime.nil? || currentTime < @untilTime)) then
        list = [] ;
        if(rand() < @frequency)
          list.push(newDemand()) ;
        end
        return list ;
      else
        return [] ;
      end
    end
    
    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------

  end # class SavDemandFactoryDirected
  
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
