#! /usr/bin/env ruby
## -*- mode: ruby -*-
## = SAV Random Allocator
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

$LOAD_PATH.addIfNeed(File.dirname(__FILE__));
$LOAD_PATH.addIfNeed(File.dirname(__FILE__) + "/../Traci");

require 'pp' ;

require 'SavAllocator.rb' ;

#--======================================================================
#++
## Sav module
module Sav

  #--============================================================
  #++
  ## class for Allcator of SavDemand
  class SavAllocatorRandom < SavAllocator

    ## register this class as sub-class of SavAllocator.
    SavAllocator.registerSubClass("random", self) ;
    
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## description of DefaultOptsions.
    DefaultConf = {
      :maxViaPoints => 5,
    } ;
                    
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## maximum ViaPoints for a SAV.
    attr_accessor :maxViaPoints ;
    
    #------------------------------------------
    #++
    ## setup.
    def setup()
      super() ;
      @maxViaPoints = getConf(:maxViaPoints) ;
    end
    
    #------------------------------------------
    #++
    ## allocate SAVs to the list of demands randomly.
    ## _demandList_:: list of SavDemand.
    ## *return* :: allocated demands.
    def allocate(demandList, savList = nil)
      savList = @simulator.savList if(savList.nil?) ;
      allocateInit() ;
      demandList.each{|demand|
        sav = savList.sample() ;
        if(sav.nil?) then
          logging(:warn, "cannot allocate SAV because no SAV exists.") ;
        elsif(! (sav.remainViaPointN() < @maxViaPoints))
          logging(:info,
                  "too much via points: " +
                  "#{sav.id} has #{sav.remainViaPointN()} points.",
                  sav.extractRemainViaPoints().map{|via| via.pos.to_a}) ;
          sav = nil
        end

        allocateDemandToSav(demand, sav, Trip.new(-1, -1)) ;
      }
      allocateFinalize() ;
      return @allocatedList ;
    end
    
    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------

  end # class SavDemandFactory
  
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
