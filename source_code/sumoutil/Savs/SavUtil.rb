#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = Sav Common Utility
## Author:: Anonymous3
## Version:: 0.0 2018/02/11 Anonymous3
##
## === History
## * [2018/02/11]: Create This File.
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

require 'Geo2D.rb' ;

#--======================================================================
#++
## Sav module
module Sav

  #--============================================================
  #++
  ## Utility Module
  module Util
    #--------------------------------------------------------------
    #++
    ## to JSON.
    ## _obj_ : object to convert.
    def toJson(obj)
      if(obj.is_a?(Array))
        return obj.map{|elm| toJson(elm)}
      elsif(obj.is_a?(Hash))
        newObj = {} ;
        obj.each{|key, value| newObj[key] = toJson(value)}
        return newObj ;
      else
        return (obj.respond_to?(:toJson) ?
                  obj.toJson() :
                  obj) ;
      end
    end
      
    #--------------------------------------------------------------
    #++
    ## store to JSON.
    ## _json_ : json hash to store.
    ## _key_ : json key.
    ## _obj_ : value object to convert.
    ## _ignoreNil_ : if true do not store if the obj is nil.
    def storeToJson(json, key, obj, ignoreNil = true)
      json[key] = toJson(obj) if (!ignoreNil || !obj.nil?) ;
    end

    #--------------------------------------------------------------
    #++
    ## average manhattan distance.
    ## Average Manhattan distance can be calculated the following form.
    ## ave(r) = r * (1 / (\pi / 2)) * \int_{0}^{\pi/2} sin(x) + cos(x) dx
    ##        = (4 / \pi) * r
    ## _pos0_, _pos1_ : two pos.  should be an instance of Geo2D::Vector.
    def averageManhattanDistance(pos0, pos1)
      return pos0.distanceTo(pos1) * (4.0 / Math::PI) ;
    end

    #--------------------------------------------------------------
    #++
    ## make sure the directory exists.
    def ensureDir(filename)
      dir = File::dirname(filename) ;
      system("mkdir -p #{dir}") ;
    end
    
    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------

  end # module Util
  Util.extend(Util) ;

  #--============================================================
  #++
  ## tentative array for planning.
  ## If, the base array is [a, b, c, d], the indexList is [2, 3],
  ## and objextList is [x, y],
  ## then the x and y are inserted just before 2nd and 3rd items
  ## so that the resulting array is [a, b, x, c, y, d].
  ## If the index is 0, insert top.
  ## If the index is negative, it counts from the last.
  ## If the index is -1, it means to insert the last.
  class TentativeArray
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## base array.
    attr_accessor :base ;
    ## index list.  should be smaller first
    attr_accessor :indexList ;
    ## object list.
    attr_accessor :objectList ;

    #------------------------------------------
    #++
    ## initialize.
    def initialize(base, idxList, objList)
      @base = base ;
      @indexList = idxList ;
      @objectList = objList ;
    end

    #------------------------------------------
    #++
    ## get nth.
    def nth(n)
      (0...@indexList.size).each{|i|
        m = kthIndex(i) ;
        if(n < m) then
          return @base[n - i] ;
        elsif(n == m) then
          return @objectList[i] ;
        end
      }
      return @base[n - @indexList.size] ;
    end
    
    #------------------------------------------
    #++
    ## get nth. (operator)
    def [](n)
      nth(n) ;
    end

    #------------------------------------------
    #++
    ## length.
    def size()
      @base.size() + @indexList.size() ;
    end

    alias :length :size ;
    
    #------------------------------------------
    #++
    ## each
    def each(&block)
      (0...size()).each{|n|
        block.call(nth(n)) ;
      }
    end
    
    #------------------------------------------
    #++
    ## map
    def map(&block)
      (0...size()).map{|n|
        block.call(nth(n)) ;
      }
    end

    #------------------------------------------
    #++
    ## get k-th index in the tentative array.
    def kthIndex(k)
      if(@indexList[k] < 0) then
        return @base.size + 1 + @indexList[k] + k ;
      else
        return @indexList[k] + k ;
      end
    end

    #------------------------------------------
    #++
    ## to_a
    def to_a()
      self.map{|obj| obj}
    end
    
  end # class TentativeArray
  
  
end # module Sav

#--======================================================================
#++
## for Geo2D.
class Geo2D::Vector
  #--------------------------------------------------------------
  #++
  ## add toJson() method for Geo2D::Vector.
  def toJson()
    json = { 'x' => @x, 'y' => @y } ;
    return json ;
  end
  
end # class Geo2D::Vector


########################################################################
########################################################################
########################################################################
if($0 == __FILE__) then

  require 'test/unit'

  #--============================================================
  #++
  ## unit test for this file.
  class TC_SavUtil < Test::Unit::TestCase
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
      base = [:a, :b, :c, :d] ;
      idx = [2, 3, -1, -1] ;
      obj = [:x, :y, :z, :w] ;
      tAry = Sav::TentativeArray.new(base, idx, obj) ;
      ary = tAry.to_a ;
      pp [{ base: base, idx: idx, obj: obj, tAry: tAry, ary: ary }]
      
      assert_equal(ary,[:a, :b, :x, :c, :y, :d, :z, :w]) ;
    end

  end # class TC_Foo < Test::Unit::TestCase
end # if($0 == __FILE__)
