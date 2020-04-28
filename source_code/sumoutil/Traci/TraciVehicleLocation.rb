#! /usr/bin/env ruby
## -*- mode: ruby -*-
## = Traci Vehicle class
## Author:: Anonymous3
## Version:: 0.0 2018/01/04 Anonymous3
##
## === History
## * [2018/01/04]: Create This File.
## * [YYYY/MM/DD]: add more
## == Usage
## * ...

def $LOAD_PATH.addIfNeed(path)
  self.unshift(path) if(!self.include?(path)) ;
end

$LOAD_PATH.addIfNeed("~/lib/ruby");
$LOAD_PATH.addIfNeed(File.dirname(__FILE__));

require 'Geo2D.rb' ;

require 'WithConfParam.rb' ;
require 'ExpLogger.rb' ;

require 'TraciUtil.rb' ;
require 'TraciDataType.rb' ;
require 'TraciCommand.rb' ;
require 'TraciClient.rb' ;

#--===========================================================================
#++
## package for SUMO
module Sumo

  #--======================================================================
  #++
  ## module for Traci
  module Traci

    #--======================================================================
    #++
    ## Traci::Vehicle
    class Vehicle < WithConfParam
      #--============================================================
      #++
      ## location class to indicate location on a map.
      class Location
        #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
        #++
        ## edge ID
        attr_accessor :edge ;
        ## location index
        attr_accessor :laneIndex ;
        ## position on the lane
        attr_accessor :posOnLane ;
        
        #--------------------------------------------------------------
        #++
        ## initialize
        def initialize(_edge, _laneIndex, _posOnLane)
          @edge = _edge ;
          @laneIndex = _laneIndex ;
          @posOnLane = _posOnLane ;
        end

        #--------------------------------------------------------------
        #++
        ## check the same
        def isCloseEnough(location, checkLaneP = false, margin = 1.0)
          if(location.edge == self.edge) then
            d = location.posOnLane - self.posOnLane ;
            if(Geo2D.abs(d) <= margin) then
              if(checkLaneP) then
                return location.laneIndex == self.laneIndex ;
              else
                return true ;
              end
            else
              return false ;
            end
          else
            return false ;
          end
        end

        #--------------------------------------------------------------
        #++
        ## check the self location is ahead of the give location
        ## on the same edge.
        def isAheadOf(location)
          return ((self.edge == location.edge) &&
                  (self.posOnLane > location.posOnLane)) ;
        end

        #--------------------------------------------------------------
        #++
        ## generate LaneID from EdgeId and LaneIndex.
        def laneId()
          return "#{@edge}_#{@laneIndex}"
        end
        
      end # class Location
      
      #--============================================================
      #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #--------------------------------------------------------------
    end # class Vehicle

  end # module Traci

end # module Sumo

########################################################################
########################################################################
########################################################################
if($0 == __FILE__) then

  require 'test/unit'

  #--============================================================
  #++
  ## unit test for this file.
  class TC_Vehicle < Test::Unit::TestCase
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
