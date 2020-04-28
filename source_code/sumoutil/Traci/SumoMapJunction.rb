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
    ## junction.
    class Junction
      #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
      #++
      ## id
      attr_accessor :id ;
      ## position (X,Y)
      attr_accessor :pos ;
      ## type
      attr_accessor :type ;
      ## edge list to connect from side of the edge
      attr_accessor :edgeIdListOut ;
      ## edge list to connect to side of the edge
      attr_accessor :edgeIdListIn ;
      
      #--------------------------------
      #++
      ## initialize
      ## _xml_:: XML element
      def initialize(xml = nil)
        @edgeIdListOut = [] ;
        @edgeIdListIn = [] ;
        scanXml(xml) if(!xml.nil?) ;
      end

      #--------------------------------
      #++
      ## scan XML definition
      ## _xml_:: XML element
      def scanXml(xml)
        @id = SumoMap.getAttrVal(xml, "id") ;
        @type = SumoMap.getAttrVal(xml, "type") ;

        x = SumoMap.getAttrVal(xml, "x").to_f ;
        y = SumoMap.getAttrVal(xml, "y").to_f ;

        @pos = Geo2D::Point.new(x, y) ;

        return self ;
      end
      
      #--------------------------------
      #++
      ## convert to JSON object (hash)
      def toJson()
        json = { 'class' => self.class.to_s }
        json['id'] = @id ;
        json['type'] = @type ;
        json['pos'] = [@pos.x, @pos.y]

        return json ;
      end
      
      #--------------------------------
      #++
      ## convert to JSON object (hash)
      ## _json_ :: JSON for one Lane.
      def scanJson(json)
        @id = json['id'] ;
        @type = json['type'] ;
        posXY = json['pos'] ;
        @pos = Geo2D::Point.sureGeoObj(posXY) ;

        return self ;
      end

      #--------------------------------
      #++
      ## get GeoObject.
      ## used in RTree.
      ## *return* :: Geo2D::GeoObject for RTree
      def geoObject()
        return @pos ;
      end

    end # class Junction
    
    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------
    
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
