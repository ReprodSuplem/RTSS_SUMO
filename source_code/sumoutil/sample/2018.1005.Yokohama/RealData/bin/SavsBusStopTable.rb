#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = Bus Stop Database
## Author:: Anonymous3
## Version:: 0.0 2018/12/23 Anonymous3
##
## === History
## * [2018/12/23]: Create This File.
## * [YYYY/MM/DD]: add more
## == Usage
## * ...

def $LOAD_PATH.addIfNeed(path)
  self.unshift(path) if(!self.include?(path)) ;
end

$LOAD_PATH.addIfNeed("~/lib/ruby");
$LOAD_PATH.addIfNeed(File.dirname(__FILE__));

require 'pp' ;
require 'csv' ;
require 'json' ;
require 'time' ;
require 'WithConfParam.rb' ;

#require 'SavsLog.rb' ;

#--======================================================================
#++
## Bus Stop Table class
class SavsBusStopTable < WithConfParam
  #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  #++
  ## description of DefaultValues.
  DefaultConf = {
    :csvFile => File.dirname(__FILE__) + "/../Summary/busStopInfo.cvs",
    nil => nil
  } ;
  
  ## key and definition map.
  KeyDefMap = {
    "識別ID" => 	[:id, :integer],
    "名称" => 		[:name, :string],
    "緯度" => 		[:lat,  :float],
    "経度" => 		[:lon,  :float],
    "乗車可否" => 	[:canPickUp, :kahi],
    "降車可否" => 	[:canDropOff, :kahi],
    "並び順" => 	[:order, :integer],
    nil => nil
  } ;
  
  ## key map. reversed KeyDefMap.
  KeyMap = {} ;
  begin
    KeyDefMap.each{|label, keyDef|
      (_key, _type) = *keyDef ;
      KeyMap[_key] = [label, _type] ;
    }
  end
  
  ## requiredKeyList
  RequiredKeyList = [
    :id,
    :name,
    :lat,
    :lon,
    :canPickUp,
    :canDropOff,
    :order,
  ] ;

  #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  #++
  ## column list.
  attr_accessor :colList ;
  ## reverse hash table of colList.
  attr_accessor :colIndex ;
  ## list of bus stop entry
  attr_accessor :stopList ;
  ## table of entry by id
  attr_accessor :tableById ;
  ## table of entry by name
  attr_accessor :tableByName ;
  ## table of entry by order
  attr_accessor :tableByOrder ;

  #--------------------------------------------------------------
  #++
  ## description of method initialize
  ## _baz_:: about argument baz.
  def initialize(conf = {})
    super(conf) ;
    setup() ;
  end

  #--------------------------------------------------------------
  #++
  ## description of method foo
  ## _csvFile_:: about argument bar
  ## *return*:: about return value
  def setup()
    @stopList = [] ;
    scanCsv(getConf(:csvFile)) ;
    buildTables() ;
  end
  
  #--------------------------------------------------------------
  #++
  ## description of method foo
  ## _csvFile_:: about argument bar
  ## *return*:: about return value
  def scanCsv(csvFile)
    CSV.foreach(csvFile){|row|
      if(@colList.nil?) then
        scanCsvHeader(row) ;
      else
        scanCsvEntry(row) ;
      end
    }
  end

  #--------------------------------------------------------------
  #++
  ## scan CSV header
  ## _row_:: header row
  ## *return* :: @colIndex ;
  def scanCsvHeader(row)
    @colList = row ;
    @colIndex = {} ;
    (0...@colList.size).each{|index|
      _label = @colList[index] ;
      if(!_label.nil? && _label.length > 0) then
        @colIndex[_label] = index ;
      end
    }
    return @colIndex ;
  end

  #--------------------------------------------------------------
  #++
  ## scan CSV data line
  ## _row_:: data row
  ## *return* :: new entry
  def scanCsvEntry(row)
    entry = Entry.new() ;
    entry.scanCsvRow(row, RequiredKeyList, @colIndex) ;
    
    @stopList.push(entry) ;
    
    return entry ;
  end

  #--------------------------------------------------------------
  #++
  ## build tables
  ## *return* :: 
  def buildTables()
    @tableByName = {} ;
    @tableById = {} ;
    @tableByOrder = {} ;
    @stopList.each{|entry|
      @tableByName[entry.getValue(:name)] = entry ;
      @tableById[entry.getValue(:id)] = entry ;
      @tableByOrder[entry.getValue(:order)] = entry ;
    }
  end

  #--------------------------------------------------------------
  #++
  ## get bus stop entry by name.
  ## *return* :: Entry
  def getStopByName(_name)
    return @tableByName[_name] ;
  end
  
  #--------------------------------------------------------------
  #++
  ## get bus stop entry by id.
  ## *return* :: Entry
  def getStopById(_id)
    return @tableById[_id] ;
  end

  #--------------------------------------------------------------
  #++
  ## get bus stop entry by order.
  ## *return* :: Entry
  def getStopByOrder(_order)
    return @tableByOrder[_order] ;
  end

  #--============================================================
  #--============================================================
  class Entry
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## json value
    attr_accessor :csv ;
    ## value table
    attr_accessor :table ;

    #------------------------------------------
    #++
    ## initialize
    def initialize()
    end

    #------------------------------------------
    #++
    ## access to value
    def getValue(key)
      case(key)
      when(:latlon)
        return getLatLon() ;
      else
        return @table[key] ;
      end
    end

    #------------------------------------------
    #++
    ## access to value
    def getLatLon()
      return [getValue(:lat), getValue(:lon)] ;
    end

    #------------------------------------------
    #++
    ## access to value
    def id()
      return getValue(:id) ;
    end

    #------------------------------------------
    #++
    ## access to value
    def order()
      return getValue(:order) - 1 ;
    end

    #------------------------------------------
    #++
    ## initialize
    def scanCsvRow(_row, _keyList, _colIndex)
      @csv = _row ;
      @table =
        SavsLog.scanCsvRowToTable(_row, _keyList, _colIndex,
                                  SavsBusStopTable::KeyMap) ;
      return self ;
    end

  end # class SavsBusStopTable::Entry

  
  #--============================================================
  #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  #--------------------------------------------------------------
end # class SavsBusStopTable

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
      stopTable = SavsBusStopTable.new() ;
      pp stopTable.tableByName ;
    end

  end # class TC_Foo < Test::Unit::TestCase
end # if($0 == __FILE__)
