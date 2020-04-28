#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = SAV Demand Factory with list of SavParty
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

require 'SavDemandFactoryMixture.rb' ;

#--======================================================================
#++
## Sav module
module Sav

  #--============================================================
  #++
  ## class for Factory of SavDemand controlled by list of SavParty.
  ## The config (demandConfig) param should be in the following format:
  ##   <Config> ::= {
  ##                  :type => "parties",
  ##                  :name => <Name>,
  ##                  :demand => <MixtureConf>,
  ##                  :partyList => [<PartyConf>, <PartyConf>, ...]
  ##                }
  ##   <Name> ::= name_of_user
  ##   <MixtureConf> ::= (see SavDemandFactoryMixture clas)
  ##   <PartyConf> ::= see SavParty class.
  ## (see {SavDemandFactoryMixture class}[file:SavDemandFactoryMixture.html].)
  ## (see {SavParty class}[file:SavParty.html].)
  class SavDemandFactoryParties < SavDemandFactory
    
    #--============================================================
    ## register the class as a components of the Mixture.
    SavDemandFactoryMixture.registerFactoryType("parties", self) ;

    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## description of DefaultOptsions.
    DefaultConf = {
      :config => {},
      :demandFactoryClass => SavDemandFactoryMixture,
      nil => nil
    } ;
                    
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## demandConfig.
    attr_accessor :demandConfig ;
    ## name of the group of parties.
    attr_accessor :name ;
    ## actual demand factory.
    attr_accessor :innerFactory ;
    ## party list.
    attr_accessor :partyList ;
    ## total weight of parties.
    attr_accessor :totalWeight ;
    
    #------------------------------------------
    #++
    ## setup.
    def setup()
      super() ;
      @demandConfig = getConf(:config) ;
      @name = @demandConfig[:name] ;
      setupInnerFactory() ;
      setupPartyList() ;
    end

    #------------------------------------------
    #++
    ## setup inner DemandFactory
    def setupInnerFactory()
      @mixtureConfig = ({ :configList => @demandConfig[:mixtureConfig] }) ;
      @innerFactory = 
        getConf(:demandFactoryClass).new(@simulator, @mixtureConfig) ;
    end

    #------------------------------------------
    #++
    ## setup party list
    def setupPartyList()
      @partyList = [] ;
      @totalWeight = 0.0 ;

      _confList = @demandConfig[:partyList] ;
      _confList.each{|_partyConf|
        _party = SavParty.newByType(self, _partyConf) ;
        @partyList.push(_party) ;
        @totalWeight += _party.weight ;
      }
      return @partyList ;
    end
    
    #------------------------------------------
    #++
    ## generate new demands in a cycle
    def newDemandListForCycle()
      list = @innerFactory.newDemandListForCycle() ;
      list.each{|demand|
        selectParty().allocDemand(demand) ;
      }
      
      return list ;
    end

    #------------------------------------------
    #++
    ## generate new demands in a cycle
    def selectParty()
      r = @totalWeight * rand() ;
      @partyList.each{|party|
        r -= party.weight ;
        return party if(r < 0.0) ;
      }
      return @partyList.last ;
    end

    #------------------------------------------
    #++
    ## get factory's name.  for SavDemand.
    def getName()
      return @name ;
    end
    
    #--------------------------------------------------------------
    #++
    ## dump party log 
    def collectPartyLog(logList = [])
      @partyList.each{|party|
        logList.push(party.dumpLogJson()) ;
      }
      return logList ;
    end
    
    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------

  end # class SavDemandFactoryParties
  
end # module Sav

require 'SavParty.rb' ;


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
