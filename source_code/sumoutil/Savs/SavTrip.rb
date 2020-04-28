#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = Trip general pair info.
## Author:: Anonymous3
## Version:: 0.0 2018/01/23 Anonymous3
##
## === History
## * [2018/01/23]: Create This File.
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
require 'SavUtil.rb' ;

#--======================================================================
#++
## Sav module
module Sav

  #--============================================================
  #++
  ## Trip
  class Trip
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## pick up
    attr_accessor :pickUp ;
    ## drop off
    attr_accessor :dropOff ;

    #--------------------------------------------------------------
    #++
    ## initialize.
    def initialize(_pickUp = nil, _dropOff = nil) 
      @pickUp = _pickUp ;
      @dropOff = _dropOff ;
    end

    #--------------------------------------------------------------
    #++
    ## ensure GeoPos
    def ensureGeoObj(klass = Geo2D::Point)
      newTrip = Trip.new(klass.sureGeoObj(@pickUp),
                         klass.sureGeoObj(@dropOff)) ;
      return newTrip ;
    end

    #--------------------------------------------------------------
    #++
    ## to JSON
    def toJson()
      json = {}
      Sav::Util.storeToJson(json, "pickUp", @pickUp) if (!@pickUp.nil?) ;
      Sav::Util.storeToJson(json, "dropOff", @dropOff) if (!@dropOff.nil?) ;
      return json ;
    end
    
    #--============================================================
    #--------------------------------------------------------------
    #++
    ## ensure Trip instance
    def self.ensureTrip(value)
      if(value.is_a?(self)) then
        return value ;
      elsif(value.is_a?(Array)) then
        return Trip.new(value[0], value[1]) ;
      else
        raise "Unknown value to ensure Trip instance:" + value.inspect ;
      end
    end
    
    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------

  end # class Trip
  
end # module Sav

########################################################################
########################################################################
########################################################################
if($0 == __FILE__) then

  require 'test/unit'

  #--============================================================
  #++
  ## unit test for this file.
  class TC_SavTrip < Test::Unit::TestCase
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
