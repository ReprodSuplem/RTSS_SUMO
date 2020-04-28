#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = SAV Service Corporation
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

require 'WithConfParam.rb' ;
require 'SavAllocator.rb' ;

#--======================================================================
#++
## Sav module
module Sav

  #--============================================================
  #++
  ## class for SAV Service Corporation
  class SavServiceCorp < WithConfParam
    
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## description of DefaultOptsions.
    DefaultConf = {
      :name => nil,
      :allocator => {},
      :price => { :constant => 200.0,  # constant part.  [yen]
                  :distance => 0.2, # distance part.  [yen/m]
                  :delay => 0.1,    # delay discount part. [-yen/s]
                  :lowerBound => nil,  # lower bound.
                                       # nil : no limit,
                                       # :zero : >= 0
                                       # :constant : >= constant part. 
                  nil => nil,
                },
      nil => nil
    } ;

    ## Corp list.
    CorpList = [] ;

    ## SubClass Table
    SubClassTable = {} ;

    #--========================================
    #------------------------------------------
    #++
    ## サブクラスの登録
    ## _typeName_: サブクラスを指定する allocMode の名前。
    ## _klass_: そのクラス。
    def self.registerSubClass(typeName, klass)
      SubClassTable[typeName] = klass ;
    end

    #--========================================
    #------------------------------------------
    #++
    ## allocMode によるサブクラスの取得。
    ## _mode_: typeName もしくは :allocMode エントリを含む Hash。
    ## *return*: サブクラス。
    def self.getSubClassByName(name)
      klass = SubClassTable[name] ;

      if(klass.nil?) then
        p [:getSubClassByName, :name, name] ;
        pp [:knownClass, SubClassTable] ;
        raise "unknown mode for SavServiceCorp sub-class." ;
      end
      
      return klass ;
    end
    
    #--========================================
    SavServiceCorp.registerSubClass("SavServiceCorp", self) ;
                    
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## name
    attr_accessor :name ;
    ## link to SavSimulator
    attr_accessor :simulator ;
    ## allocator
    attr_accessor :allocator ;
    ## nSav max;
    attr_accessor :nSavMax ;
    
    ## earned money ;
    attr_accessor :income ;
    ## price constand part
    attr_accessor :priceConst ;
    ## price distanct part. per meter
    attr_accessor :pricePerMeter ;
    ## price delay part. per sec
    attr_accessor :pricePerSec ;
    ## price lower boundary
    attr_accessor :priceLowerBound ;
    
    #--------------------------------------------------------------
    #++
    ## 初期化
    def initialize(_savSim, _conf = {})
      super(_conf) ;
      setup(_savSim) ;
      CorpList.push(self) ;
    end
    
    #--------------------------------------------------------------
    #++
    ## setup.
    def setup(_savSim = @simulator)
      @simulator = _savSim ;
      @name = getConf(:name) ;
      @nSavMax = getConf(:nSavMax) || getConf(:savN)  ;
      @savList = [] ;
      setupAllocator(getConf(:allocatorConf)) ;
      setupPriceParam(getConf(:price)) ;
      @income = 0.0 ;
    end
    
    #------------------------------------------
    #++
    ## allocate SAVs to the list of demands randomly.
    def setupAllocator(_conf)
      allocConf = @simulator.getConf(:allocatorConf).dup.update(_conf) ;
      @allocator =
        Sav::SavAllocator.newAllocatorByConf(@simulator,
                                             nil,
                                             allocConf) ;
    end

    #------------------------------------------
    #++
    ## allocate SAVs to the list of demands randomly.
    def setupPriceParam(priceConf)
      @priceConstant = priceConf[:constant] ;
      @pricePerMeter = priceConf[:distance] ;
      @pricePerSec = priceConf[:delay] ;

      @priceLowerBound = priceConf[:lowerBound] ;
      if(@priceLowerBound.is_a?(String)) then
        @priceLowerBound = @priceLowerBound.intern() ;
      end

    end

    #------------------------------------------
    #++
    ## add new SavVehicle if need.
    def addNewSavVehicleIfNeed()
      if(@savList.size < @nSavMax) then
        newSav = @allocator.addNewSavVehicleToBase() ;
        if(newSav.is_a?(Array)) then
          @savList.concat(newSav) ;
        else
          @savList.push(newSav) ;
        end
      end
    end

    #------------------------------------------
    #++
    ## allocateOne
    def allocateOne(demand)
      @allocator.allocateOne(demand, @savList) ;
    end
    
    #------------------------------------------
    #++
    ## calculate price for the demand.
    def askPriceFor(demand, paidP = true)
      _dist = demand.getTripDistance_Manhattan() ;

      _duration = demand.getTripTime_Move() ;
      
      _time = _dist / AveSpeed ;
      _delay = _duration - _time ;
      _delay = 0.0 if(_delay < 0) ;

      case(@priceLowerBound)
      when nil
        _price = (@priceConstant +
                  (@pricePerMeter * _dist) -
                  (@pricePerSec * _delay)) ;
      when :zero
        _price = (@priceConstant +
                  (@pricePerMeter * _dist) -
                  (@pricePerSec * _delay)) ;
        _price = 0.0 if(_price < 0.0) ;
      when :constant
        _variablePart = (@pricePerMeter * _dist) - (@pricePerSec * _delay) ;
        _price = (@priceConstant +
                  (_variablePart >= 0.0 ? _variablePart : 0.0)) ;
      else
        raise "unknown lower bound type: " + @priceLowerBound.inspect ;
      end
      
      @income += _price ;
      
      return _price ;
    end

    AveSpeed = (30.0 * 1000 / 60 / 60) ;
#    AveSpeed = (15.0 * 1000 / 60 / 60) ;

    #------------------------------------------
    #++
    ## dumpLogJson
    def dumpLogJson(baseJson = {}) ;
      json = baseJson.dup ;
      json.update({ :name => @name,
                    :nSavMax => @nSavMax,
                    :income => @income,
                    :allocator => @allocator.dumpLogJson() }) ;
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
