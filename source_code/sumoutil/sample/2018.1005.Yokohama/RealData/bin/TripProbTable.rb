#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = Trip Probability Table
## Author:: Anonymous3
## Version:: 0.0 2018/12/25 Anonymous3
##
## === History
## * [2018/12/25]: Create This File.
## * [YYYY/MM/DD]: add more
## == Usage
## * ...

def $LOAD_PATH.addIfNeed(path)
  self.unshift(path) if(!self.include?(path)) ;
end

$LOAD_PATH.addIfNeed("~/lib/ruby");
$LOAD_PATH.addIfNeed(File.dirname(__FILE__));

require 'pp' ;
require 'json' ;
require 'WithConfParam.rb' ;


#--======================================================================
#++
## trip probability table.
## An element of the table is the probability in which
## a trip between O-D (pickUp - dropOff) occurs.
class TripProbTable < WithConfParam
  #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  #++
  ## description of DefaultValues.
  DefaultValues = { :foo => :bar } ;
  ## description of DefaultOptsions.
  DefaultConf = { :nPickUp => nil,
                  :nDropOff => nil,
                  nil => nil } ;

  #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  #++
  ## size of pickUp point list.
  attr_accessor :nPickUp ;
  ## size of dropOff point list.
  attr_accessor :nDropOff ;
  ## singular prob. table.
  attr_accessor :probSingular ;
  ## weight for factored prob.
  attr_accessor :weightFactored ;
  ## sum of factored prob in diagonal.
  attr_accessor :sumDiagProb ;
  ## factored prob. in pickUp.
  attr_accessor :probPickUp ;
  ## factored prob. in dropOff.
  attr_accessor :probDropOff ;

  ## singularList
  attr_accessor :singularList ;

  ## factored prob. in dropOff.
  attr_accessor :originalFreqTable ;
  
  ## factored prob. in dropOff.
  attr_accessor :originalProbTable ;

  #--------------------------------------------------------------
  #++
  ## initialize
  ## _conf_:: configulation hash table.
  def initialize(_conf = {})
    super(_conf) ;
    @nPickUp = getConf(:nPickUp) ;
    @nDropOff = getConf(:nDropOff) ;
  end

  #--------------------------------------------------------------
  #++
  ## setup by 
  ## _freqTable_:: frequency table.
  ## *return*:: self.
  def setupByFreqTable(_freqTable)
    @originalFreqTable = _freqTable ;
    
    @nPickUp = _freqTable.size ;
    @nDropOff = _freqTable[0].size ;

    _sum = 0.0 ;
    _freqTable.each{|freqRow|
      freqRow.each{|freq|
        _sum += freq.to_f  ;
      }
    }
    
    @probSingular = [] ;
    @probPickUp = [] ;
    @probDropOff = [] ;
    (0...@nPickUp).each{|i|
      @probSingular[i] = [] ;
      (0...@nDropOff).each{|j|
        _v = _freqTable[i][j].to_f / _sum ;
        @probSingular[i][j] = _v ;
        @probPickUp[i] = @probPickUp[i].to_f + _v ;
        @probDropOff[j] = @probDropOff[j].to_f + _v ;
      }
    }

    adjustWeightFactored() ;

    adjustDiagSumProb() ;

    return self ;
  end

  #--------------------------------------------------------------
  #++
  ## adjust @weightFactored.
  ## *return*:: result.
  def adjustWeightFactored()
    @weightFactored = 1.0 ;
    (0...@nPickUp).each{|i|
      (0...@nDropOff).each{|j|
        @weightFactored -= @probSingular[i][j].to_f ;
      }
    }
    return @weightFactored ;
  end
  
  #--------------------------------------------------------------
  #++
  ## adjust @diagSumProb.
  ## *return*:: result.
  def adjustDiagSumProb()
    @sumDiagProb = 0.0 ;
    (0...@nPickUp).each{|k|
      @sumDiagProb += @probPickUp[k] * @probDropOff[k] ;
    }
    return @sumDiagProb ;
  end

  #--------------------------------------------------------------
  #++
  ## adjust factored prob tables (pickUp, dropOff) with singular probs.
  ## _target_:: target probs.
  ## *return*:: self ;
  def adjustProbFactoredWithSingular(_target)
    _freqTable = [] ;

    (0...@nPickUp).each{|i|
      _freqTable[i] = [] ;
      (0...@nDropOff).each{|j|
        _freqTable[i][j] = _target.getProb(i,j) - @probSingular[i][j].to_f ;
      }
    }

    _workProbTable = TripProbTable.new() ;
    _workProbTable.setupByFreqTable(_freqTable) ;

    @probPickUp = _workProbTable.probPickUp ;
    @probDropOff = _workProbTable.probDropOff ;

    return self ;
  end
  
  #--------------------------------------------------------------
  #++
  ## calculate factored probability.
  ## _i_:: index i
  ## _j_:: index j
  ## *return*:: result.
  def calcProbFactored(i,j)
    v = (i == j ? 0.0 : @probPickUp[i] * @probDropOff[j]) ;
    return v / (1.0 - @sumDiagProb) ;
  end
  
  #--------------------------------------------------------------
  #++
  ## calculate factored probability.
  ## _i_:: index i
  ## _j_:: index j
  ## *return*:: result.
  def getProb(i,j)
    v = @probSingular[i][j].to_f ;
    v += @weightFactored * calcProbFactored(i,j) ;
    
    v = 0.0 if(v<0.0) ;
    v = 1.0 if(v>1.0) ;
    
    return v ;
  end

  #--------------------------------------------------------------
  #++
  ## dup
  ## *return*:: new one.
  def dup()
    newTable = self.class.new() ;
    newTable.copyFrom(self) ;
    return newTable ;
  end

  #--------------------------------------------------------------
  #++
  ## copy important slots.
  ## *return*:: 
  def copyFrom(_table)
    @nPickUp = _table.nPickUp ;
    @nDropOff = _table.nDropOff ;
    @probSingular = _table.probSingular.dup ;
    @weightFactored = _table.weightFactored ;
    @sumDiagProb = _table.sumDiagProb ;
    @probPickUp = _table.probPickUp.dup ;
    @probDropOff = _table.probDropOff.dup ;

    return self ;
  end

  #--------------------------------------------------------------
  #++
  ## drop singular probs
  ## *return*:: self
  def dropSingular()
    @probSingular = Array.new(@nPickUp){[]} ;
    @weightFactored = 1.0 ;
    return self ;
  end

  #--------------------------------------------------------------
  #++
  ## calculate Kullback-Leibler divergence.
  ## _table_:: other prob table.
  ## *return*:: divergence.
  def calcKLDivergenceTo(_table)
    _div = 0.0 ;
    (0...@nPickUp).each{|i|
      (0...@nDropOff).each{|j|
        _p = getProb(i,j) ;
        _diffLog = (Math.log(_p + EpsProb) -
                    Math.log(_table.getProb(i,j) + EpsProb)) ;
        _div += _p * _diffLog ;
      }
    }
    return _div ;
  end

  ## 確率最小値。
  EpsProb = 1.0e-20 ;

  #--------------------------------------------------------------
  #++
  ## find top N diff in prob
  ## _n_:: number of top n
  ## _table_:: other prob table.
  ## *return*:: list of [diff,i,j]
  def findTopNDiff(_n, _table)
    _list = Array.new(_n,nil) ;
    (0...@nPickUp).each{|i|
      (0...@nDropOff).each{|j|
        _diff = getProb(i,j) - _table.getProb(i,j) ;
        (0..._n).each{|k|
          if(_list[k].nil? || _list[k][0] < _diff) then
            _list.insert(k,[_diff,i,j]) ;
            _list.pop ;
            break ;
          end
        }
      }
    }

    return _list ;
  end

  #--------------------------------------------------------------
  #++
  ## adjust Singular value.  (old, wrong?)
  ## _n_:: number of top n
  ## _target_:: target prob. table.
  ## *return*:: self.
  def adjustSingularToward_old(_n, _target)
    _topNDiff = _target.findTopNDiff(_n, self) ;

    @singularList = [] ;
    
    _topNDiff.each{|diffInfo|
      (_diff, _i, _j) = *diffInfo ;
      
      _sumI = 0.0 ;
      (0...@nDropOff).each{|j| _sumI += _target.getProb(_i,j) ;} ;
      _sumJ = 0.0 ;
      (0...@nPickUp).each{|i| _sumJ += _target.getProb(i,_j) ;} ;

      _p = _target.getProb(_i,_j) ;

      _r = (_p - _sumI * _sumJ)/(1.0 + _p - _sumI - _sumJ) ;

      @probSingular[_i][_j] = @probSingular[_i][_j].to_f + _r ;

      @singularList.push([_i,_j,@probSingular[_i][_j]]) ;
    }

    adjustProbFactoredWithSingular(_target) ;

    adjustWeightFactored() ;
    adjustDiagSumProb() ;

    return self ;
  end

  #--------------------------------------------------------------
  #++
  ## adjust Singular value.  (new, right?)
  ## 差分には未対応。繰り返しは使えない。
  ## _n_:: number of top n
  ## _target_:: target prob. table.
  ## *return*:: self.
  def adjustSingularToward(_n, _target)
    _topNDiff = _target.findTopNDiff(_n, self) ;

    @singularList = [] ;
    
    _topNDiff.each{|diffInfo|
      (_diff, _i, _j) = *diffInfo ;
      
      _sumI = 0.0 ;
      (0...@nDropOff).each{|j| _sumI += _target.getProb(_i,j) ;} ;
      _sumJ = 0.0 ;
      (0...@nPickUp).each{|i| _sumJ += _target.getProb(i,_j) ;} ;

      _p = _target.getProb(_i,_j) ;

      _r = (_p - _sumI * _sumJ)/(1.0 - _sumI * _sumJ) ;

      @probSingular[_i][_j] = @probSingular[_i][_j].to_f + _r ;

      @singularList.push([_i,_j,@probSingular[_i][_j]]) ;
    }

    adjustProbFactoredWithSingular(_target) ;

    adjustWeightFactored() ;
    adjustDiagSumProb() ;

    return self ;
  end
  

  #--------------------------------------------------------------
  #++
  ## to Json
  ## *return*:: json object
  def toJson()
    _obj = { :nPickUp => @nPickUp,
             :nDropOff => @nDropOff,
             :probSingular => @probSingular,
             :weightFactored => @weightFactored,
             :sumDiagProb => @sumDiagProb,
             :probPickUp => @probPickUp,
             :probDropOff => @probDropOff,
             :singularList => @singularList } ;
    return _obj ;
  end

  #--------------------------------------------------------------
  #++
  ## setup by Json
  ## *return*:: self
  def setupByJson(_json)
    @nPickUp = _json[:nPickUp] ;
    @nDropOff = _json[:nDropOff] ;
    @probSingular = _json[:probSingular] ;
    @weightFactored = _json[:weightFactored] ;
    @sumDiagProb = _json[:sumDiagProb] ;
    @probPickUp = _json[:probPickUp] ;
    @probDropOff = _json[:probDropOff] ;
    @singularList = _json[:singularList] ;
    
    return self ;
  end

  #--------------------------------------------------------------
  #++
  ## to JsonString
  ## *return*:: json string
  def toJsonString(_prettyP)
    if(_prettyP) then
      return JSON.pretty_generate(toJson()) ;
    else
      return JSON.generate(toJson()) ;
    end
  end
  
  #--------------------------------------------------------------
  #++
  ## save in JSON.
  ## *return*:: 
  def saveJsonFile(_filename, _prettyP = true)
    open(_filename,"w"){|ostrm|
      _jsonstr = toJsonString(_prettyP) ;
      ostrm.puts(_jsonstr) ;
    }
  end

  #--------------------------------------------------------------
  #++
  ## load from JSON.
  ## *return*:: 
  def loadJsonFile(_filename)
    open(_filename,"r"){|istrm|
      _json = JSON.parse(istrm.read(), {:symbolize_names => true}) ;
      setupByJson(_json) ;
    }
  end

  #--------------------------------------------------------------
  #++
  ## get Random Trip (pair of pickUp and dropOff)
  ## *return*:: 
  def getRandomTrip()
    _i = nil ;
    _j = nil ;
    
    if(@singularList) then
      r = rand() ;
      @singularList.each{|_singular|
        (_i,_j,_p) = *_singular ;
        r -= _p ;
        if(r < 0) then
          return [_i, _j] ;
        end
      }
    end

    getAnsP = false ;
    until(getAnsP) 
      r = rand() ;
      _i = 0 ;
      (0...@nPickUp).each{|k|
        r -= @probPickUp[k] ;
        if(r < 0) then
          _i = k ;
          break ;
        end
      }

      r = rand() ;
      _j = 0 ;
      (0...@nDropOff).each{|k|
        r -= @probDropOff[k] ;
        if(r < 0) then
          _j = k ;
          break ;
        end
      }

      getAnsP = true if (_i != _j) ;
    end

    return [_i, _j] ;
    
  end

  
  #--============================================================
  #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  #--------------------------------------------------------------
end # class Foo

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
    TestData = "../Summary/probMixture5.json" ;

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
      ptab = TripProbTable.new() ;
      ptab.loadJsonFile(TestData) ;
      pp ptab ;

      (0...10).each{|k|
        p [k, ptab.getRandomTrip()] ;
      }
    end

  end # class TC_Foo < Test::Unit::TestCase
end # if($0 == __FILE__)
