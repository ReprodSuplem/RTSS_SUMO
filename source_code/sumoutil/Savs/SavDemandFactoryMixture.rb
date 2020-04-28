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
  ## class for Factory of SavDemand.
  ## The config (demandConfig) param should be in the following format:
  ##   <ConfigList> ::= [ <Config>, <Config>, ... ]
  ##   <Config> ::= { :type => ("directed" | "parties" | ...),
  ##                  ... # depend on each type.
  ##                }
  class SavDemandFactoryMixture < SavDemandFactory
    
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## description of DefaultOptsions.
    DefaultConf = {
      :configList => [],
      nil => nil
    } ;

    ## map table from type name to factory class
    FactoryTypeTable = { nil => nil }
    #--============================================================
    #--------------------------------------------------------------
    #++
    ## Register a factory class.
    ## *typeName* :: a name of the factory class. used as a key.
    ## *klass* :: class object of the factory.
    def self.registerFactoryType(typeName, klass)
      FactoryTypeTable[typeName] = klass ;
    end
                    
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## list of config
    attr_accessor :configList ;
    ## list of factory
    attr_accessor :factoryList ;
    
    #------------------------------------------
    #++
    ## setup.
    def setup()
      super() ;
      @configList = getConf(:configList) ;
      setupFactoryList(@configList) ;
    end

    #------------------------------------------
    #++
    ## setup.
    def setupFactoryList(_configList)
      @factoryList = [] ;
      _configList.each{|config|
        type = config[:type] ;
        klass = FactoryTypeTable[type] ;
        raise ("unknown factory config type:" + type) if(klass.nil?) ;

        newConfig = @conf.dup ;
        newConfig.delete(:configList) ;
        newConfig[:config] = config ;

        factory = klass.new(@simulator, newConfig) ;
        @factoryList.push(factory) ;
      }
    end
    
    #------------------------------------------
    #++
    ## generate new demands in a cycle
    def newDemandListForCycle()
      list = [] ;
      @factoryList.each{|factory|
        sublist = factory.newDemandListForCycle() ;
        list.concat(sublist) ;
      }
      return list ;
    end

    #--------------------------------------------------------------
    #++
    ## dump party log 
    def collectPartyLog(logList = [])
      @factoryList.each{|factory|
        logList = factory.collectPartyLog(logList) ;
      }
      return logList ;
    end
    
    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------

  end # class SavDemandFactoryDirected
  
end # module Sav

require 'SavDemandFactoryDirected.rb' ;
require 'SavDemandFactoryParties.rb' ;
require 'SavDemandFactoryLiteral.rb' ;

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
