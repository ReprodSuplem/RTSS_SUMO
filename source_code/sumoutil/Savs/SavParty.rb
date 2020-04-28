#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = SavParty class
## Author:: Anonymous3
## Version:: 0.0 2018/12/14 Anonymous3
##
## === History
## * [2018/12/15]: Create This File.
## * [YYYY/MM/DD]: add more
## == Usage
## * ...

def $LOAD_PATH.addIfNeed(path)
  self.unshift(path) if(!self.include?(path)) ;
end

$LOAD_PATH.addIfNeed(File.dirname(__FILE__));
$LOAD_PATH.addIfNeed(File.dirname(__FILE__) + "/../Traci");

require 'pp' ;

require 'WithConfParam.rb' ;

require 'SavDemandFactoryParties.rb' ;

#--======================================================================
#++
## Sav module
module Sav

  #--============================================================
  #++
  ## class for a party of passenger agents that share the same policy.
  ## The config (partyConfig) param should be denoted in
  ## "partyList" slot.
  ## Its format is:
  ##   <Config> ::= {
  ##                  :name => <Name>,
  ##                  :weight => <Weight>,
  ##                  :type => <PolicyType>,
  ##                  ... (other params)
  ##                }
  ##   <Name> ::= string of party's name.
  ##   <Weight> ::= weight of this party in the party list.
  ##   <PolicyType> ::= "softmax"
  ## (see {SavDemandFactoryMixture class}[file:SavDemandFactoryMixture.html].)
  class SavParty < WithConfParam
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## description of DefaultOptsions.
    DefaultConf = {
      :name => "",
      :weight => 1.0,
      :type => "softmax",
      
      :alpha => 0.1,
      :epsilon => 0.1,
      :temperature => 1.0,
      
      :unitDistValue => 1.0,
      :unitTimeValue => 1.0,
      
      nil => nil
    } ;
    
    ## table of sub-types.
    SubTypeTable = {} ;

    #--============================================================
    #--------------------------------------------------------------
    #++
    ## register sub-type.
    ## _typeName_: name of type.
    ## _klass_: class of the sub-type agent.
    def self.registerSubType(typeName, klass)
      SubTypeTable[typeName] = klass ;
    end

    #--============================================================
    #--------------------------------------------------------------
    #++
    ## get sub-type
    ## _typeName_: name of type.
    def self.getSubType(typeName)
      return SubTypeTable[typeName] ;
    end

    #--============================================================
    #--------------------------------------------------------------
    #++
    ## new SavParty by type.
    ## _factory_: an instance of SavDemanfFactoryParties.
    ## _conf_: config of SavParty, which should include :type.
    def self.newByType(_factory, conf)
      type = conf[:type] ;
      klass = self.getSubType(type) ;
      if(klass) then
        return klass.new(_factory, conf) ;
      else
        raise "unknown SavParty type: #{type.inspect} in #{conf.inspect}" ;
      end
    end

    #--============================================================
    #--============================================================
    SavParty.registerSubType("softmax", self) ;

    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## factory. (demand factory user group)
    attr_accessor :factory ;
    ## name.
    attr_accessor :name ;
    ## weight.
    attr_accessor :weight ;
    ## type
    attr_accessor :type ;
    ## list of handled demands.
    attr_accessor :demandList ;

    ## corp-value Table
    attr_accessor :corpValueTable ;
    ## corp-demand Table
    attr_accessor :corpDemandTable ;

    ## alpha parameter in learning (stepsize)
    attr_accessor :alpha ;
    ## epsilon parameter in learning (exploration)
    attr_accessor :epsilon ;
    ## temperature parameter in learning (softmax)
    attr_accessor :temperature ;

    ## value for unit distance.
    attr_accessor :unitDistValue ;
    ## value for unit time.
    attr_accessor :unitTimeValue ;

    #--------------------------------------------------------------
    #++
    ## 初期化。
    ## _factory_: 所属する SavDemandFactoryParty。
    ## _conf_: 設定。
    def initialize(_factory, conf = {})
      super(conf) ;

      @factory = _factory ; 
      @name = getConf(:name) ;
      @weight = getConf(:weight) ;
      @type = getConf(:type).intern ;
      @demandList = [] ;

      setupLearning() ;
    end

    #--------------------------------------------------------------
    #++
    ## 学習準備
    def setupLearning()
      @corpValueTable = {} ;
      @corpDemandTable = {} ;
      
      @alpha = getConf(:alpha) ;
      @epsilon = getConf(:epsilon) ;
      @temperature = getConf(:temperature) ;

      @unitDistValue = getConf(:unitDistValue) ;
      @unitTimeValue = getConf(:unitTimeValue) ;
    end
    
    #--------------------------------------------------------------
    #++
    ## 名前取得。
    def getName(fullP = true)
      if(fullP) then
        return @factory.getName() + ":" + @name.to_s ;
      else
        return @name.to_s ;
      end
    end

    #--------------------------------------------------------------
    #++
    ## デマンドをこの party と結びつける。
    ## _demand_: 当のデマンド。
    def allocDemand(_demand)
      _demand.setPassenger(self) ;
      @demandList.push(_demand) ;
    end
      
    #--------------------------------------------------------------
    #++
    ## サービスCorp選択。
    ## このクラスでは、ランダムに選ぶ。
    ## _serviceList_: SavService のリスト。
    ## _demand_: サービスを選択する当のデマンド。
    ## *return*: 選択したSavService。
    def selectCorp(corpList, demand)
      case(@type)
      when :softmax ;
        return selectCorp_SoftMax(corpList, demand) ;
      when :random ;
        return selectCorp_Random(corpList, demand) ;
      else
        raise "unsupported selection type:" + @type.inspect ;
      end
    end

    #------------------------------------------
    #++
    ## SoftMax で corp を選ぶ。 
    def selectCorp_Random(corpList, demand)
      return corpList.sample() ;
    end
    
    #------------------------------------------
    #++
    ## SoftMax で corp を選ぶ。 
    def selectCorp_SoftMax(corpList, demand)
      setupCorpTableByList(corpList) ;

      # @epsilon でランダム選択。
      if(rand() < @epsilon) then
        return selectCorp_Random(corpList, demand) ;
      end
      
      # それ以外は、softmax 選択。
      
      currentMaxValue = getMaxValueInTable() ;
      currentMaxValue = 0.0 if(currentMaxValue.nil?) ;
      
      expSum = 0.0 ;
      corpList.each{|corp|
        expSum += calcExpValueForCorp(corp, currentMaxValue) ;
      }
      r = expSum * rand() ;

      selectedCorp = nil ;
      corpList.each{|corp|
        r -= calcExpValueForCorp(corp, currentMaxValue) ;
        if(r <= 0.0) then
          selectedCorp = corp ;
          break ;
        end
      }
      selectedCorp = corpList.sample if(selectedCorp.nil?) ;

      return selectedCorp ;
    end

    #----------------------
    #++
    ## corpValueTable 中の最大値を求める。なければ、nil ;
    def getMaxValueInTable() 
      v = nil ;
      @corpValueTable.keys.each{|corp|
        if(@corpDemandTable[corp].size > 0) then
          u = @corpValueTable[corp] ;
          v = u if(v.nil? || u > v) ;
        end
      }
      return v ;
    end

    #----------------------
    #++
    ## 
    def calcExpValueForCorp(corp, maxValue)
      v = ((@corpDemandTable[corp].size > 0) ?
             @corpValueTable[corp] :
             maxValue) ;
      ev = Math::exp(v / @temperature) ;
#      p [:expValue, corp.name, v, ev] ;
      return ev ;
    end

    #----------------------
    #++
    ## corpList がすべて登録済みかチェック。
    def setupCorpTableByList(corpList)
      corpList.each{|corp|
        if(@corpValueTable[corp].nil?) then
          @corpValueTable[corp] = 0.0 ;
          @corpDemandTable[corp] = [] ;
        end
      }
      return corpList ;
    end
    
    #--------------------------------------------------------------
    #++
    ## デマンド完了処理。corpTable のアップデート。
    def completeDemand(demand)
      price = demand.corp.askPriceFor(demand) ;
      demand.price = price ;
      updateCorpTable(demand.corp, demand, price) ;
    end

    #--------------------------------
    #++
    ## corp table を更新。
    def updateCorpTable(corp, demand, price)
      unitValue = calcUnitValueFor(demand, price) ;

      oldValue = @corpValueTable[corp] ;
      newValue = (1.0 - @alpha) * oldValue + @alpha * unitValue ;
      @corpValueTable[corp] = newValue ;
#      p [:update, corp.name, oldValue, unitValue, newValue] ;

      @corpDemandTable[corp].push(demand) ;
    end
      
    #--------------------------------
    #++
    ## 真の単位価値を求める。
    def calcUnitValueFor(demand, price)
      _dist = demand.getTripDistance_Euclid() ;
      _duration = demand.getTripTime_Whole() ;

      v = _dist * @unitDistValue - _duration * @unitTimeValue - price ;

      u = v / _dist ;

      return u ;
    end

    #------------------------------------------
    #++
    ## dumpLogJson
    def dumpLogJson(baseJson = {}) ;
      _corpValueTable = {} ;
      @corpValueTable.each{|corp,value|
        _corpValueTable[corp.name] = value ;
      }

      json = baseJson.dup ;
      json.update({ :name => @name,
                    :weight => @weight,
                    :alpha => @alpha,
                    :epsilon => @epsilon,
                    :temperature => @temperature,
                    :unitDistValue => @unitDistValue,
                    :unitTimeValue => @unitTimeValue,
                    :corpValueTable => _corpValueTable }) ;
      return json ;
    end

    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------
  end # class SavParty
  
end # module Sav

########################################################################
########################################################################
########################################################################
if($0 == __FILE__) then

  require 'test/unit'

  #--============================================================
  #++
  ## unit test for this file.
  class TC_Foo < Test::Unit::TestCase
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

    #----------------------------------------------------
    #++
    ## about test_a
    def test_a
      pp [:test_a] ;
      assert_equal("foo-",:foo.to_s) ;
    end

  end # class TC_Foo < Test::Unit::TestCase
end # if($0 == __FILE__)
