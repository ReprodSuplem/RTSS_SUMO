#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = Sumo Map Handler
## Author:: Anonymous3
## Version:: 0.0 2018/01/07 Anonymous3
##
## === History
## * [2018/01/07]: Create This File.
## * [YYYY/MM/DD]: add more
## == Usage
## * ...

require 'optparse' ;
require 'pp' ;
require 'json' ;

def $LOAD_PATH.addIfNeed(path)
  self.unshift(path) if(!self.include?(path)) ;
end

$LOAD_PATH.addIfNeed("~/lib/ruby");

require 'Geo2D.rb' ;
require 'RTree.rb' ;
require 'ItkXml.rb' ;

$LOAD_PATH.addIfNeed(File.dirname(__FILE__));

require 'WithConfParam.rb' ;
require 'ExpLogger.rb' ;

require 'TraciUtil.rb' ;

#--===========================================================================
#++
## package for SUMO
module Sumo

  #--======================================================================
  #++
  ## description of class Foo.
  class SumoMap < WithConfParam

    #--============================================================
    #--============================================================
    #++
    ## edge
    class Edge
      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #++
      ## id
      attr_accessor :id ;
      ## lane list.
      attr_accessor :laneList ;
      ## from junction ID
      attr_accessor :fromId ;
      ## to junction ID
      attr_accessor :toId ;
      ## from junction
      attr_accessor :from ;
      ## to junction
      attr_accessor :to ;
      ## type
      attr_accessor :type ;
      
      #--------------------------------
      #++
      ## initialize
      ## _xml_:: XML element
      def initialize(xml = nil)
        scanXml(xml) if(!xml.nil?) ;
      end
      
      #--------------------------------
      #++
      ## scan XML definition
      ## _xml_:: XML element
      def scanXml(xml)
        @id = SumoMap.getAttrVal(xml, "id") ;
        @fromId = SumoMap.getAttrVal(xml, "from") ;
        @toId = SumoMap.getAttrVal(xml, "to") ;
        @type = SumoMap.getAttrVal(xml, "type") ;
        @laneList = [] ;
        xml.each_element("lane") {|laneXml|
          lane = Lane.new() ;
          lane.scanXml(laneXml, self) ;
          @laneList.push(lane) ;
        }
        return self ;
      end

      #--------------------------------
      #++
      ## convert to JSON object (hash)
      def toJson()
        json = { 'class' => self.class.to_s }
        json['id'] = @id ;
        json['type'] = @type ;
        json['from'] = @fromId ;
        json['to'] = @toId ;

        _laneList = @laneList.map{|lane| lane.toJson() ;}
        json['laneList'] = _laneList ;

        return json ;
      end

      #--------------------------------
      #++
      ## scan JSON object (hash)
      ## _json_ :: JSON for one Edge.
      def scanJson(json)
        @id = json['id'] ;
        @fromId = json['from'] ;
        @toId = json['to'] ;
        @type = json['type'] ;

        _laneList = json['laneList'] ;

        @laneList = _laneList.map{|laneJson|
          lane = Lane.new() ;
          lane.scanJson(laneJson, self) ;
          lane ;
        }

        return self ;
      end

      #--------------------------------
      #++
      ## first lane
      def firstLane()
        return @laneList.first() ;
      end

      #--------------------------------
      #++
      ## get length
      def length()
        return firstLane().length() ;
      end

      #--------------------------------
      #++
      ## get speed
      def speed()
        return firstLane().speed() ;
      end
      
      #--------------------------------
      #++
      ## get shape
      def shape()
        return firstLane().shape() ;
      end

      #--------------------------------
      #++
      ## get originalId
      def originalId()
        return firstLane().originalId() ;
      end
      
      #--------------------------------
      #++
      ## get GeoObject.
      ## used in RTree.
      ## *return* :: Geo2D::GeoObject for RTree
      def geoObject()
        return firstLane().geoObject() ;
      end

      #--------------------------------
      #++
      ## get foot point from the reference point.
      ## _reference_ :: reference point
      ## *return* :: foot point
      def footPointFrom(reference)
        return geoObject().footPointFrom(reference) ;
      end

      #--------------------------------
      #++
      ## get the span of foot point from the reference point.
      ## _reference_ :: reference point
      ## _forStop_ :: if true, adjust span for stop position.
      ## *return* :: span
      def footPointSpanFrom(reference, forStop = false)
        span = geoObject().footPointSpanFrom(reference) ;
        span = length() if(span > length()) ;
        if(forStop) then
          return validSpan(span) ;
        else
          return span ;
        end
      end

      #--------------------------------
      #++
      ## get valid span for stop the vehicle.
      ## if span is zero, increase it to MinSpanForStop.
      ## if MinSpanForStop is too large for the edge,
      ## use the mid point of the edge.
      ## _span_ :: original span.
      ## *return* :: span
      def validSpan(span)
        if(span < MinSpanForStop) then
          if(MinSpanForStop > length()) then
            return length() / 2.0 ;
          else
            return MinSpanForStop ;
          end
        else
          return span ;
        end
      end

      ## Minimum Span for Stop position
      MinSpanForStop = 0.5 ;

      #--------------------------------
      #++
      ## bbox method for RTree
      ## *return* :: boundary box as an instance of Geo2d::Box() ;
      def shape()
        return firstLane().shape() ;
      end

      #--------------------------------
      #++
      ## get exit end of the lane 0
      ## *return* :: Geo2D::Point instance
      def getStartPoint()
        shape().firstPoint() ;
      end

      #--------------------------------
      #++
      ## get exit end of the lane 0
      ## *return* :: Geo2D::Point instance
      def getEndPoint()
        shape().lastPoint() ;
      end
      
      #--------------------------------
      #++
      ## check permission for a certain type
      ## _type_ :: type symbol.  Nomally :private (private car).
      ## *return* :: true if has permission
      def checkPermissionFor(type = :private)
        @laneList.each{|lane|
          # if one of lane is permitted, true.
          return true if(lane.checkPermissionFor(type)) ;
        }
        # all lanes are not permitted, false.
        return false ;
      end

      #--------------------------------
      #++
      ## check the type is included in the excludeTypeList.
      ## _excludeTypeList_ :: array of type symbol.
      ## *return* :: true if the edge is included in the excludeTypeList.
      def shouldBeExcluded(excludeTypeList)
        return excludeTypeList.include?(@type) ;
      end

      #--------------------------------
      #++
      ## get connected edge ids from this edge.
      ## *return* :: the list of edge. 
      def getConnectedEdgeIds()
        return @to.edgeIdListOut ;
      end
      
      #--------------------------------
      #++
      ## get connected edges from this edge.
      ## _map_ :: mother map 
      ## *return* :: the list of edge. 
      def getConnectedEdges(map)
        return getConnectedEdgeIds().map{|edgeId| map.edgeTable[edgeId]} ;
      end

      #--------------------------------
      #++
      ## check the edge is opposite
      ## *return* :: true if the given edge is opposite.
      def isOppositeEdge(edge)
        if(self.to == edge.from && edge.to == self.from) then
          return true ;
        else
          margin = (StandardLaneWidth *
                    (self.laneList.size + edge.laneList.size)) ;
          
          if(self.getStartPoint().distanceTo(edge.getEndPoint()) < margin &&
             self.getEndPoint().distanceTo(edge.getStartPoint()) < margin) then
            return true ;
          else
            return false ;
          end
        end
      end

      ## Standard Lane Width
      StandardLaneWidth = 3.5 ; ## normal road: 2.7-3.5, highway: 3.25-3.5

      #--------------------------------
      #++
      ## get opposite edge
      ## _map_:: mother map.
      ## *return* :: opposite edge if exists.  otherwise, nil.
      def getOppositeEdge(map)
        edgeList = getConnectedEdges(map) ;
        edgeList.each{|edge|
          return edge if(isOppositeEdge(edge)) ;
        }
        return nil ;
      end

      #--------------------------------
      #++
      ## get target edge for U-turn
      ## _map_:: mother map.
      ## *return* :: edge
      def getEdgeForUTurn(map)
        edge = (getOppositeEdge(map) ||
                getConnectedEdges(map).sample()) ;

        return edge ;
      end

      #--------------------------------
      #++
      ## get target Pointfor U-turn
      ## _map_:: mother map.
      ## *return* :: Geo2D::Point
      def getPointForUTurn(map)
        edge = getEdgeForUTurn(map) ;

        if(edge.nil?) then
          raise SumoException.new("The edge is dead-end:" + self.inspect(),
                                  { :edge => self }) ;
        end

        return edge.getEndPoint() ;
      end

      #--------------------------------
      #++
      ## re-define inspect
      alias inspect_original inspect ;
      def inspect()
        dummy = self.dup ;
        dummy.remove_instance_variable('@from') ;
        dummy.remove_instance_variable('@to') ;
        dummy.laneList = @laneList.map{|lane| lane.id}
        return dummy.inspect_original ;
      end

    end # class Edge
    
  end # class SumoMap

end # module Sumo
  
########################################################################
########################################################################
########################################################################
if($0 == __FILE__) then

  require 'test/unit'
  require 'TimeDuration.rb' ;

  #--============================================================
  #++
  ## unit test for this file.
  class TC_Foo < Test::Unit::TestCase
    #--::::::::::::::::::::::::::::::::::::::::::::::::::
    #++
    ## desc. for TestData
    SampleNetFile = "/home/noda/work/iss/SAVS/Data/2018.0104.Tsukuba/TsukubaCentral.small.net.xml" ;

    SampleJsonFile = '/tmp/SumoMap.tmp.json' ;
    SampleJsonFile2 = '/tmp/SumoMap.tmp2.json' ;

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
    ## scan XML file
    def test_a
    end

  end # class TC_Foo < Test::Unit::TestCase
end # if($0 == __FILE__)
