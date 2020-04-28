#! /usr/bin/env ruby
## -*- mode: ruby -*-
## = SAV Allocator Guild.
## Author:: Anonymous3
## Version:: 0.0 2018/12/15 Anonymous3
##
## === History
## * [2018/12/15]: Create This File.
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

require 'SavAllocator.rb' ;
require 'SavServiceCorp.rb' ;

#--======================================================================
#++
## Sav module
module Sav

  #--============================================================
  #++
  ## class for a group of allocators for SavDemand
  class SavAllocatorGuild < SavAllocator
    
    ## register this class as sub-class of SavAllocator.
    SavAllocator.registerSubClass("guild", self) ;

    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## description of DefaultOptsions.
    DefaultConf = {
      :corpConf => [],
      nil => nil
    } ;
                    
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## member list of service corporation.
    attr_accessor :corpList ;
    
    #------------------------------------------
    #++
    ## setup.
    def setup()
      super() ;
      setupCorpList(getConf(:corpConf)) ;
    end
    
    #------------------------------------------
    #++
    ## setup members
    def setupCorpList(corpConf)
      @corpList = [] ;
      corpConf.each{|_conf|
        corp = newServiceCorp(_conf) ;
        @corpList.push(corp) ;
      }
    end

    #------------------------------------------
    #++
    ## create new SavServiceCorp
    def newServiceCorp(corpConf)
      klass = SavServiceCorp.getSubClassByName(corpConf[:class]) ;
      corp = klass.new(@simulator, corpConf) ;
      return corp ;
    end
    
    #--------------------------------------------------------------
    #++
    ## add sav vehicle and assign to a sav base (override)
    ## _savBase_:: sav base (ignored)
    ## *return*:: new sav
    def addNewSavVehicleToBase(savBase = nil)
      _savList = [] ;
      @corpList.each{|corp|
        _newSav = corp.addNewSavVehicleIfNeed() ;
        _savList.push(_newSav) ;
      }
      return _savList ;
    end
    
    #--------------------------------
    #++
    ## get max number of sav. (used only for guild)
    def nSavMax()
      sum = 0 ;
      @corpList.each{|corp|
        sum += corp.nSavMax ;
      }
      return sum ;
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
        corp = demand.selectCorp(@corpList) ;
        corp.allocateOne(demand) ;
      }
      allocateFinalize();

      return @allocatedList ;
    end

    #------------------------------------------
    #++
    ## allocate init
    ## *return* :: allocated demands.
    def allocateInit()
      super() ;
      @corpList.each{|corp|
        corp.allocator.allocateInit() ;
      }
    end
    
    #------------------------------------------
    #++
    ## allocate finalize
    ## *return* :: allocated demands.
    def allocateFinalize()
      @corpList.each{|corp|
        corp.allocator.allocateFinalize() ;
        @allocatedList.concat(corp.allocator.allocatedList) ;
        @cancelledList.concat(corp.allocator.cancelledList) ;
      }
      super() ;
    end

    #--------------------------------------------------------------
    #++
    ## dump log in json object.
    def dumpLogJson(baseJson = {})
      json = baseJson.dup.update({ :type => :guild }) ;
#      json = super(json) ;
      
      corpListJson = [] ;
      @corpList.each{|corp|
#        p [:corp, corp.name]
        corpListJson.push(corp.dumpLogJson()) ;
      }
      json[:corpList] = corpListJson ;
      
      return json ;
    end
    
    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------

  end # class SavDemandGuild
  
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
