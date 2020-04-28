#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = Workbench for SavSimulation
## Author:: Anonymous3
## Version:: 0.0 2018/10/20 Anonymous3
##
## === History
## * [2018/10/20]: Create This File.
## * [YYYY/MM/DD]: add more
## == Usage
## * ...

def $LOAD_PATH.addIfNeed(path)
  self.unshift(path) if(!self.include?(path)) ;
end

# $LOAD_PATH.addIfNeed("~/lib/ruby");
$LOAD_PATH.addIfNeed(File.dirname(__FILE__));
$LOAD_PATH.addIfNeed(File.dirname(__FILE__) + "/../Traci");

require 'optparse' ;
require 'pp' ;
require 'WithConfParam.rb'

#--======================================================================
#++
## SavSim を実行する作業台
class SavSimBench < WithConfParam
  #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  #++
  ## description of DefaultOptsions.
  DefaultConf = {
    :simType => :mixture,   ## or :random
    :simConf => nil,
    :sumoConf => nil,
    :simOpts => [],
    :comDirBase => "../",
    :toolDir => "Tools/",
    :convDir => "Traci/",
    :simDir  => "Savs/",
    :osmSuffix => ".osm",
    :mapXmlSuffix => ".net.xml",
    :mapJsonSuffix => ".net.json",
    :mapDumpSuffix => ".net.dump",
    :featureJsonSuffix => ".feature.json",
    :troubleWaySuffix => ".troubleWay.list",
    :junctionSize => 20,
    :workDir => ".",  # runSavSim を実行する directory. 
    nil => nil } ;

  ## output separator
  CommandSep = ("-" * 30) ;

  #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  #++
  ## OSM filename
  attr_accessor :mapOsm ;
  ## Map dirname
  attr_accessor :mapDir ;
  ## Map basename
  attr_accessor :mapBase ;

  ## XML Map filename
  attr_accessor :mapXml ;
  ## Json Map filename
  attr_accessor :mapJson ;
  ## Dump Map filename
  attr_accessor :mapDump ;
  ## featureJson
  attr_accessor :featureJson ;
  ## troubleWay
  attr_accessor :troubleWay ;

  #--------------------------------------------------------------
  #++
  ## 初期化
  ## _osmMap_:: specify OSM filename
  def initialize(_osmMap = nil, _conf = {})
    super(_conf) ;
    setupMapFiles(_osmMap) if(! _osmMap.nil?) ;
  end

  #--------------------------------------------------------------
  #++
  ## マップファイル設定
  ## _osmMap_:: specify OSM filename
  def setupMapFiles(_osmMap)
    @mapOsm = _osmMap ;
    @mapDir = File.dirname(@mapOsm) ;
    @mapBase = File.basename(@mapOsm, getConf(:osmSuffix)) ;

    @mapXml = @mapDir + "/" + @mapBase + getConf(:mapXmlSuffix) ;
    @mapJson = @mapDir + "/" + @mapBase + getConf(:mapJsonSuffix) ;
    @mapDump = @mapDir + "/" + @mapBase + getConf(:mapDumpSuffix) ;
    @featureJson = @mapDir + "/" + @mapBase + getConf(:featureJsonSuffix) ;
    @troubleWay = @mapDir + "/" + @mapBase + getConf(:troubleWaySuffix) ;
  end

  #--------------------------------------------------------------
  # run simulations
  #-----------------------------------------
  #++
  ## run SavSimulator
  def runSavSim(*opts)
    Dir.chdir(getConf(:workDir)){|workDir|
      case(getConf(:simType))
      when :random ;
        runSavSimRandom(*opts) ;
      when :mixture ;
        runSavSimMixture(nil, *opts) ;
      else
        raise "unknown simulation type: " + getConf(:simType) ;
      end
    }
  end
  
  #-----------------------------------------
  #++
  ## run command
  ## _com_:: shell command
  def runCommand(com) ;
    puts CommandSep ;
    puts "com: #{com}" ;
    system(com) ;
  end

  #------------------------------------------
  #++
  ## simulation Command (Random)
  ## _opts_:: simulation config file
  def comSavSimRandom(*opts)
    fullOpts = getConf(:simOpts) + opts ;
    com = (getConf(:comDirBase) + getConf(:simDir) + "runSavSimRandom" +
           " " + fullOpts.join(" ") +
           " #{getConf(:sumoConf)} #{@mapJson} #{@mapDump}") ;
    return com ;
  end

  #----------------------
  #++
  ## run simulation 
  ## _simConf_:: simulation config file
  ## _*opts_:: additional option for simulator
  def runSavSimRandom(*opts)
    com = comSavSimRandom(*opts) ;
    runCommand(com) ;
  end

  #------------------------------------------
  #++
  ## simulation Command (Mixture)
  ## _simConf_:: simulation config file
  def comSavSimMixture(_simConf = nil, *opts)
    _simConf = getConf(:simConf) if(_simConf.nil?) ;
    fullOpts = getConf(:simOpts) + opts ;
    raise "no config file is specified." if(_simConf.nil?) ;

    com = (getConf(:comDirBase) + getConf(:simDir) + "runSavSimMixture" +
           " " + fullOpts.join(" ") +
           " " + _simConf) ;
    return com ;
  end

  #----------------------
  #++
  ## run simulation 
  ## _simConf_:: simulation config file
  ## _*opts_:: additional option for simulator
  def runSavSimMixture(_simConf = nil, *opts)
    com = comSavSimMixture(_simConf, *opts) ;
    runCommand(com) ;
  end

  #------------------------------------------
  #++
  ## net convert Command (list)
  ## _netConvOpts_:: option list for netconvert.
  ## *return*:: shell command for net convertion.
  def comListMapConv(netConvOpts = [])
    comList = [] ;

    comFilter = getConf(:comDirBase) + getConf(:toolDir) + "filterSavsTagInOsm" ;

    comFilter1 = comFilter + " --feature #{@featureJson} #{@mapOsm}" ;
    comList.push(comFilter1) ;

    comFilter2 = comFilter + " --trouble #{@troubleWay} #{@mapOsm}" ;
    comList.push(comFilter2) ;

    comNetConv =<<"________________________________________ComEnd__"
netconvert \
  -X never \
  --osm-files #{@mapOsm}  \
  -o #{@mapXml}  \
  --lefthand  \
  --osm.all-attributes true \
  --junctions.join true \
  --junctions.join-dist #{getConf(:junctionSize)} \
  --output.street-names true \
  --output.original-names true \
  --remove-edges.isolated true \
  --remove-edges.input-file #{@troubleWay} \
  #{netConvOpts.join(" ")}
________________________________________ComEnd__
    
    comList.push(comNetConv) ;

    comNetConvJson = (getConf(:comDirBase) + getConf(:convDir) +
                      "convSumoMapXml2Json" +
                      "  #{@mapXml} #{@mapJson} #{@mapDump}") ;
    comList.push(comNetConvJson) ;

    return comList ;
  end
    
  #----------------------
  #++
  ## run simulation 
  ## _simConf_:: simulation config file
  def runMapConv()
    comList = comListMapConv() ;

    comList.each{|com|
      runCommand(com) ;
    }
  end

  #--============================================================
  #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  #--------------------------------------------------------------
end # class SavSimBench

########################################################################
########################################################################
########################################################################
if($0 == __FILE__) then

  require 'test/unit'

  #--============================================================
  #++
  ## unit test for this file.
  class TC_SavSimBench < Test::Unit::TestCase
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

  end # class TC_SavSimBench 
end # if($0 == __FILE__)
