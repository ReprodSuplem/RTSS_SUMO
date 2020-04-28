#! /usr/bin/env ruby
# coding: utf-8
## -*- mode: ruby -*-
## = Savs Log class
## Author:: Anonymous3
## Version:: 0.0 2018/12/20 Anonymous3
##
## === History
## * [2018/12/20]: Create This File.
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
require 'gnuplot.rb' ;

require 'TripProbTable.rb' ;


#--======================================================================
#++
## SavsLog handling class.
class SavsLog < WithConfParam
  #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  #++
  ## description of DefaultValues.
  DefaultValues = { :foo => :bar } ;
  ## description of DefaultOptsions.
  DefaultConf = { :name => nil,
                  nil => nil } ;

  ## key definition map.  from header name (String) to key symbol (Symbol).
  KeyDefMap = {
    "日時" => 		[:submitTime, :time],
    "デマンドID" => 	[:demandId, :integer],
    "予約種別" => 	[:requestType, :string],
    "乗客ユニークID" =>  [:userUniqueId, :integer],
    "passengerID" => 	[:passengerId, :integer],
    "車両ID" => 	[:savId, :integer],
    "乗車人数" => 	[:nPassenger, :integer],
    "キャンセル時刻" => 	[:cancelTime, :time],
    "乗車時刻" =>	[:pickUpTime, :time],
    "降車時刻" =>	[:dropOffTime, :time],
    "乗車位置（緯度、経度）" => 	[:pickUpLatLon, :latlon],
    "乗車乗降ポイント" => 	[:pickUpPoint, :string],
    "降車位置（緯度、経度）" => 	[:dropOffLatLon, :latlon],
    "降車乗降ポイント" => 	[:dropOffPoint, :string],
    "乗車予定時間（初回）" => 	[:pickUpPlannedTimeInit, :time],
    "乗車予定時間（最終）" => 	[:pickUpPlannedTimeFinal, :time],
    "降車予定時間（初回）" => 	[:dropOffPlannedTimeInit, :time],
    "降車予定時間（最終）" => 	[:dropOffPlannedTimeFinal, :time],
    "希望乗車時間" => 		[:pickUpRequiredTime, :time],
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
    :submitTime, 
    :demandId, 
    :requestType, 
    :userUniqueId, 
    :passengerId,
    :savId,
    :nPassenger,
    :cancelTime,
    :pickUpTime,
    :dropOffTime,
    :pickUpLatLon,
    :pickUpPoint,
    :dropOffLatLon,
    :dropOffPoint,
    :pickUpPlannedTimeInit,
    :pickUpPlannedTimeFinal,
    :dropOffPlannedTimeInit,
    :dropOffPlannedTimeFinal,
    :pickUpRequiredTime,
  ] ;

  ## 国民の休日 (文字列)
  NationalHolidayStrList = ["2018-10-08",
                            "2018-11-03",
                            "2018-11-23",
                           ] ;
  ## 国民の休日 (Time)
  NationalHolidayList = [] ;
  begin
    NationalHolidayStrList.each{|daystr|
      NationalHolidayList.push(Time.parse(daystr)) ;
    }
  end

  ## 営業時間
  WorkHourList = (9..20).to_a ;

  #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  #++
  ## name of the SavsLog.
  attr_accessor :name ;
  ## column list.
  attr_accessor :colList ;
  ## reverse hash table of colList.
  attr_accessor :colIndex ;
  ## list of entry
  attr_accessor :entryList ;
  ## children (sub log list).
  attr_accessor :children ;
  ## bus stop table
  attr_accessor :busStopTable ;

  ## frequency table of pick-up / drop-off
  attr_accessor :freqTable ;
  
  ## frequency table of pick up
  attr_accessor :freqTablePickUp ;
  
  ## frequency table of drop off
  attr_accessor :freqTableDropOff

  ## probability table of pick-up / drop-off
  attr_accessor :probTable ;
  
  ## factored probability table of pick-up / drop-off
  attr_accessor :probTableFactored ;
  
  ## mixture probability table of pick-up / drop-off with singular probs.
  attr_accessor :probTableMixture ;
  
  ## number of singular probs 
  attr_accessor :nSingular ;
  
  ## probability table of pick up
#  attr_accessor :probTablePickUp ;
  
  ## probability table of drop off
#  attr_accessor :probTableDropOff

  #--------------------------------------------------------------
  #++
  ## description of method initialize
  ## _baz_:: about argument baz.
  def initialize(conf = {})
    super(conf) ;
    @entryList = [] ;
    @children = [] ;
    @name = getConf(:name) ;
    setupBusStopTable() ;
  end

  #--------------------------------------------------------------
  #++
  ## setup bus stop table
  def setupBusStopTable()
    @busStopTable = SavsBusStopTable.new() ;
    SavsLogEntry.setBusStopTable(@busStopTable) ;
  end
  
  #--------------------------------------------------------------
  #++
  ## size of log
  ## *return*:: ログサイズ（エントリ数）
  def size()
    return @entryList.size ;
  end
  
  #--------------------------------------------------------------
  #++
  ## merge another log.
  ## _log_:: another log
  def merge(log)
    @entryList.concat(log.entryList) ;
  end

  #--------------------------------------------------------------
  #++
  ## scan glob of CSV file
  ## _csvFilePattern_:: pattern to specify glob of CSV files.
  def scanCsvGlob(csvFilePattern)
    Dir.glob(csvFilePattern){|file|
      child = SavsLog.new() ;
      child.scanCsv(file) ;
#      p [:scanCsvGlob, :child, file, child.size] ;
      @children.push(child) ;
      merge(child) ;
    }
    return self ;
  end
  
  #--------------------------------------------------------------
  #++
  ## scan CSV file
  ## _csvFile_:: CSV file name.
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
    entry = SavsLogEntry.new() ;
    entry.scanCsvRow(row, RequiredKeyList, @colIndex) ;
    
    # drop the entry if no demandId.
    if(entry.isValid()) ;
      @entryList.push(entry) ;
    else
      entry = nil ;
    end
    
    return entry ;
  end

  #--------------------------------------------------------------
  #++
  ## convert to JSON object
  ## *return* :: an Array.
  def toJson()
    return @entryList.map{|entry| entry.toJson() ; }
  end
  
  #--------------------------------------------------------------
  #++
  ## convert to Json Strng
  ## _prettyP_ :: pretty print if true. 1 line per entry if :line.
  ##              otherwise, condenced format.
  def toJsonString(prettyP = false)
    case(prettyP)
    when(true) ;
      return JSON.pretty_generate(toJson()) ;
    when(:line) ;
      _strList = @entryList.map{|entry| JSON.generate(entry.toJson())} ;
      return "[\n  #{_strList.join(",\n  ")}\n]" ;
    else
      return JSON.generate(toJson()) ;
    end
  end

  #--------------------------------------------------------------
  #++
  ## save to Json file.
  ## _jsonFile_:: filename to save.
  ## _prettyP_ :: pretty print if true. 1 line per entry if :line.
  ##              otherwise, condenced format.
  def saveJsonFile(jsonFile, prettyP = false)
    open(jsonFile,"w") {|ostrm|
      saveJsonStream(ostrm, prettyP) ;
    }
  end

  #--------------------------------------------------------------
  #++
  ## save Json to stream
  ## _strm_:: stream to output
  ## _prettyP_ :: pretty print if true. 1 line per entry if :line.
  ##              otherwise, condenced format.
  def saveJsonStream(strm, prettyP = false)
    strm.puts(toJsonString(prettyP)) ;
  end

  #--------------------------------------------------------------
  #++
  ## scan Json file.
  ## _jsonFile_:: filename to scan
  def scanJsonFile(_jsonFile)
    open(_jsonFile,"r"){|strm|
      scanJsonString(strm.read()) ;
    }
  end

  #--------------------------------------------------------------
  #++
  ## scan Json string.
  ## _jsonStr_:: filename to scan
  def scanJsonString(_jsonStr)
    _json = JSON.parse(_jsonStr, {:symbolize_names => true}) ;
    _json.each{|_entryJson|
      scanJsonEntry(_entryJson) ;
    }
  end

  #--------------------------------------------------------------
  #++
  ## scan Json Entry
  ## _jsonEntry_:: json for one entry.
  def scanJsonEntry(_jsonEntry)
    entry = SavsLogEntry.new() ;
    entry.scanJson(_jsonEntry) ;
    @entryList.push(entry) ;
  end

  #--------------------------------------------------------------
  #++
  ## pickUp の数。
  def nPickUp()
    if(!@freqTablePickUp.nil?) then
      return @freqTablePickUp.size ;
    else
      return 0 ;
    end
  end

  #--------------------------------------------------------------
  #++
  ## dropOff の数。
  def nDropOff()
    if(!@freqTableDropOff.nil?) then
      return @freqTableDropOff.size ;
    else
      return 0 ;
    end
  end
  
  #--------------------------------------------------------------
  #++
  ## 各種処理のまとめ。
  ## _k_:: nSingular を指定。
  def procAll(_k)
    buildFreqTables() ;
    calcProbTableFromFreq() ;
    calcMixtureProb(_k) ;
  end
  
  #--------------------------------------------------------------
  #++
  ## 度数分布表作成
  def buildFreqTables()
    @freqTable = [] ;
    @freqTablePickUp = [] ;
    @freqTableDropOff = [] ;

    @entryList.each{|entry|
      _pickUp = entry.getPickUpBusStop() ;
      _dropOff = entry.getDropOffBusStop() ;

      incMatrixEntry(@freqTable, _pickUp.order, _dropOff.order) ;
      incVectorEntry(@freqTablePickUp, _pickUp.order) ;
      incVectorEntry(@freqTableDropOff, _dropOff.order) ;
    }

    iMax = @freqTablePickUp.size ;
    jMax = @freqTableDropOff.size ;
    (0...iMax).each{|i|
      @freqTable[i] = [] if(@freqTable[i].nil?) ;
      (0...jMax).each{|j|
        @freqTable[i][j] = 0 if(@freqTable[i][j].nil?) ;
      }
      @freqTablePickUp[i] = 0 if(@freqTablePickUp[i].nil?) ;
    }
    (0...jMax).each{|j|
      @freqTableDropOff[j] = 0 if(@freqTableDropOff[j].nil?) ;
    }
  end

  #--------------------------------
  #++
  ## 行列要素のincrement.
  def incMatrixEntry(matrix, i, j)
    v = matrix[i] ;
    if(v.nil?) then
      v = [] ;
      matrix[i] = v ;
    end

    incVectorEntry(v,j) ;
  end

  #--------------------------------
  #++
  ## ベクトル要素のincrement.
  def incVectorEntry(vector, j)
    c = vector[j] ;
    c = 0 if(c.nil?) ;

    vector[j] = c + 1 ;
  end

  #--------------------------------------------------------------
  #++
  ## 度数分布表のCSV出力
  def dumpFreqTableToCsv(file)
    CSV.open(file,"wb"){|csv|
      header = ['pivot'] ;
      (0...@freqTableDropOff.size).each{|j| header.push(j)} ;
      csv << header ;
      (0...@freqTablePickUp.size).each{|i|
        csv << ([i] + @freqTable[i]) ;
      }
    }
  end

  #--------------------------------------------------------------
  #++
  ## calcProbTableFromFreq()
  def calcProbTableFromFreq()
    @probTable = TripProbTable.new() ;
    @probTable.setupByFreqTable(@freqTable) ;
    
    return @probTable ;
  end

  #--------------------------------------------------------------
  #++
  ## calc. singular prob.
  ## _n_ :: number of singular probs.
  ## *return*:: self.
  def calcMixtureProb(_n)
    @nSingular = _n ;
    @probTableFactored = @probTable.dup().dropSingular() ;
    
    _topNDiff = @probTable.findTopNDiff(_n, @probTableFactored) ;

#    p [:topNDiff, _topNDiff] ;

    @probTableMixture =
      @probTableFactored.dup().adjustSingularToward(_n,@probTable) ;

    return self ;
  end

  #--------------------------------------------------------------
  #++
  ## get singular prob list in MixtureProb.
  ## *return*:: the list.
  def getSingularListInMixtureProb()
    return @probTableMixture.singularList() ;
  end
    
  #--------------------------------------------------------------
  #++
  ## get factored frequency
  def getFactoredFreq(i,j)
    if(i == j) then
      return 0 ;
    else
      return (@freqTablePickUp[i] * @freqTableDropOff[j]) ;
    end
  end

  #--------------------------------------------------------------
  #++
  ## get factored probability
  def getFactoredProb(i,j)
    return @probTable.calcProbFactored(i,j) ;
  end

  #--------------------------------------------------------------
  #++
  ## get factored probability
  def getFactoredProb0(i,j)
    v = (i == j ? 0 : @probTablePickUp[i] * @probTableDropOff[j]) ;
    return v/(1-@probFactoredDiagSum) ;
  end

  #--------------------------------------------------------------
  #++
  ## 汎用プロット
  def plotGeneric(basename, _conf, &block)
    if(@name) then
      _conf = _conf.dup ;
      _conf[:title] = _conf[:title] + " [#{@name}]" ;
    end

    _resolution = [nPickUp()*2, nDropOff()*2] ; 
      
    defaultConf = {:pathBase => basename,
                   :resolution => _resolution,
                   :approxMode => :hann,
                   :xlabel => "from",
                   :ylabel => "to",
                   :zlabel => "freq.",
#                   :logscale => :z,
                   :logscale => nil,
#                   :contour => true,
                   :contour => false,                   
                   :noztics => true,
                   :view => [0, 359.9999],
#                   :view => [30, 60],
                   :tgif => true,
                   nil => nil} ;
    actualConf = defaultConf.dup.update(_conf) ;

    Gnuplot::directDgrid3dPlot(actualConf) {|gplot|
      gplot.command("set palette rgbformulae 22,13,-31") ;
      if(_conf[:cbMax]) then
        gplot.command("set cbrange [0.000:#{_conf[:cbMax]}]") ;
      end
#      gplot.command("set view map") ;
      (0...@freqTablePickUp.size).each{|i|
        (0...@freqTableDropOff.size).each{|j|
          value = block.call(i,j) ;
          gplot.dpDgrid3dPlot(i,j,value) ;
        }
      }
    }
  end
  
  #--------------------------------------------------------------
  #++
  ## 度数分布表のプロット
  def plotFreqTable(basename, _conf = {})
    if(_conf[:title].nil?) then
      _conf = _conf.dup ;
      _conf[:title] = "freq. table" ;
    end
    plotGeneric(basename,_conf){|i,j|
      @freqTable[i][j]
    }
  end

  #--------------------------------------------------------------
  #++
  ## 度数分布表のプロット（要素分解）
  def plotFreqFactored(basename, _conf = {})
    if(_conf[:title].nil?) then
      _conf = _conf.dup ;
      _conf[:title] = "freq. table (factored)" ;
    end
    plotGeneric(basename, _conf){|i,j|
      getFactoredFreq(i,j) ;
    }
  end

  #--------------------------------------------------------------
  #++
  ## 確率分布表のプロット
  def plotProbTable(basename, _conf = {})
    if(_conf[:title].nil?) then
      _conf = _conf.dup ;
      _conf[:title] = "prob. table" ;
    end
    plotGeneric(basename,_conf){|i,j|
      @probTable.getProb(i,j) ;
    }
  end

  #--------------------------------------------------------------
  #++
  ## 確率分布表のプロット（要素分解）
  def plotProbFactored(basename, _conf = {})
    if(_conf[:title].nil?) then
      _conf = _conf.dup ;
      _conf[:title] = "prob. table (factored)" ;
    end
    plotGeneric(basename, _conf){|i,j|
      getFactoredProb(i,j) ;
    }
  end

  #--------------------------------------------------------------
  #++
  ## 確率分布表のプロット（要素分解 + 特異分布)
  def plotProbMixture(basename, _conf = {})
    if(_conf[:title].nil?) then
      _conf = _conf.dup ;
      _conf[:title] = "prob. table (mixture)(n=#{@nSingular})" ;
    end
    plotGeneric(basename, _conf){|i,j|
      @probTableMixture.getProb(i,j) ;
    }
  end

  #--------------------------------------------------------------
  #++
  ## 確率分布表の保存
  ## _filename_:: 保存するファイル名。
  def saveProbMixture(_filename, _prettyP = true)
    @probTableMixture.saveJsonFile(_filename, _prettyP) ;
  end

  #--------------------------------------------------------------
  #++
  ## 曜日によるフィルタリング
  ## _source_:: フィルタするもとのデータ。SavsLogもしくはEntryList
  ## _type_:: 平日 (:weekday) もしくは休日 (:holiday) を指定する。
  def filterByDayTypeFrom(_source, _type)
    if(_source.is_a?(SavsLog)) then
      return filterByDayTypeFrom(_source.entryList, _type) ;
    else
      @entryList = [] ;
      _source.each{|entry|
        _submitTime = entry.table[:submitTime] ;
        _weekendP = (_submitTime.saturday?() || _submitTime.sunday?()) ;
        _nationalP = false ;
        NationalHolidayList.each{|_day|
          _nationalP = true if(_day.yday == _submitTime.yday) ;
        }
        _holidayP = _weekendP || _nationalP ;
        if((_type == :holiday && _holidayP) ||
           (_type == :weekday && !_holidayP)) then
          @entryList.push(entry) ;
        end
      }
    end
    return @entryList ;
  end

  #--------------------------------------------------------------
  #++
  ## day type による filtered log を新たに作成。
  ## _dayType_:: :weekday or :holiday .
  ## _procP_:: 各種テーブルを作成するかどうか。
  ## _name_:: テーブルの名前。nil だと、_dayType の文字列化とする。
  def genFilteredSavsLogByDayType(_dayType, _procP = true, _name = nil)
    _name = _dayType.to_s if(_name.nil?) ;

    _newLog = SavsLog.new({:name => _name}) ;
    _newLog.filterByDayTypeFrom(self, _dayType) ;

    _newLog.procAll(@nSingular) if(_procP) ;

    return _newLog ;
  end

  #--------------------------------------------------------------
  #++
  ## 時刻によるフィルタリング
  ## _source_:: フィルタするもとのデータ。SavsLogもしくはEntryList
  ## _hour_:: 時刻。数値。
  ## _axis_:: 基準とする時刻のタイプ。 {:submitTime, :pickUpTime, :dropOffTime}
  def filterByHourFrom(_source, _hour, _axis = :submitTime)
    if(_source.is_a?(SavsLog)) then
      return filterByHourFrom(_source.entryList, _hour) ;
    else
      @entryList = [] ;
      _source.each{|entry|
        _time = entry.table[_axis] ;
        if(_time.is_a?(Time) && _time.hour == _hour) then
          @entryList.push(entry) ;
        end
      }
    end
    return @entryList ;
  end
  
  #--------------------------------------------------------------
  #++
  ## 時刻による filtered log を新たに作成。
  ## _hour_:: 時刻（時）の数字。
  ## _axis_:: 基準とする時刻のタイプ。 {:submitTime, :pickUpTime, :dropOffTime}
  ## _procP_:: 各種テーブルを作成するかどうか。
  ## _name_:: テーブルの名前。nil だと、もとの @name に_hour の文字列化を追加。
  def genFilteredSavsLogByHour(_hour, _axis = :submitTime,
                               _procP = true, _name = nil)
    if(_name.nil?) then
      _name = @name + ("(hour=%02d)" % _hour) ;
    end

    _newLog = SavsLog.new({:name => _name}) ;
    _newLog.filterByHourFrom(self, _hour, _axis) ;

    _newLog.procAll(@nSingular) if(_procP) ;

    return _newLog ;
  end

  #--------------------------------------------------------------
  #++
  ## 時刻による filtered log 同士の距離をプロット
  ## _pathBase_:: gnuplot ファイルの保存パス。
  def plotDistAmongHourlyProb(_pathBase)
    @hourlyLogs = {} ;
    SavsLog::WorkHourList.each{|_hour|
      _subLog = genFilteredSavsLogByHour(_hour) ;
      @hourlyLogs[_hour] = _subLog ;
    }

    _res = SavsLog::WorkHourList.size * 2 + 1;
    _rangeMin = SavsLog::WorkHourList.first ;
    _rangeMax = SavsLog::WorkHourList.last ;

    _plotConf = {:pathBase => _pathBase,
                 :title => "distances between hourly prob. table (#{@name})",
                 :resolution => [_res,_res],
                 :approxMode => :hann,
                 :xlabel => "hour X",
                 :ylabel => "hour Y",
                 :zlabel => "dist.",
#                 :logscale => :z,
                 :logscale => nil,
                 :contour => true,
#                 :contour => false,                   
                 :noztics => true,
                 :view => [0, 359.9999],
#                 :view => [30, 60],
                 :tgif => true,
#                 :tgif => false,
                 nil => nil} ;

    Gnuplot::directDgrid3dPlot(_plotConf) {|gplot|
#        gplot.command("set palette rgbformulae 22,13,-31") ;
      gplot.command("set palette grey") ;        
      gplot.command("set cbrange [2.000:6.000]") ;
      gplot.command("set xrange [#{_rangeMin}:#{_rangeMax}]") ;
      gplot.command("set yrange [#{_rangeMin}:#{_rangeMax}]") ;
      SavsLog::WorkHourList.each{|x|
        SavsLog::WorkHourList.each{|y|
          next if(x==y) ;
          probTableX = @hourlyLogs[x].probTable ;
          probTableY = @hourlyLogs[y].probTable ;
          dist = probTableX.calcKLDivergenceTo(probTableY) ;
          p [x,y,dist] ;
          value = dist ;
#          value = 1.0 / (dist * dist + 1.0) ;
#          value = Math.log(dist + 1.0) ;
#          value = 1.0 / (dist + 1.0) ;
          gplot.dpDgrid3dPlot(x,y,value) ;
        }
      }
    }
  end

  #--============================================================
  #--------------------------------------------------------------
  #++
  ## convert value to Ruby value by type.
  ## 
  def self.scanCsvRowToTable(_row, _keyList, _colIndex, _keyMap)
    _table = {} ;
    _keyList.each{|_key|
      (_label, _type) = *(_keyMap[_key]) ;
      _index = _colIndex[_label] ;
      _data = _row[_index] ;
      _value = SavsLog.convertValueByType(_data, _type) ;
      _table[_key] = _value ;
    }
    return _table ;
  end
    
  #--============================================================
  #--------------------------------------------------------------
  #++
  ## convert value to Ruby value by type.
  ## 
  def self.convertValueByType(_data, _type)
    return nil if(_data.nil? ||
                  (_data.is_a?(String) && _data.length == 0)) ;
    
    case(_type)
    when(:string) ;
      return _data.to_s ;
    when(:time) ;
      begin
        return Time.parse(_data) ;
      rescue
        return nil ;
      end
    when(:integer) ;
      return _data.to_i ;
    when(:float) ;
      return _data.to_f ;
    when(:latlon) ;
      if(_data.is_a?(String)) then
        _latlon = (_data.split(' ')).map{|v| v.to_f()} ;
      elsif(_data.is_a?(Array)) then
        _latlon = (_data.map{|v| v.to_f()}) ;
      end
      return _latlon ;
    when(:kahi) ;
      case(_data)
      when("可") ; return true ;
      when("否") ; return false ;
      else
        raise "unknown 可否 type value:#{_data}" ;
      end
    else
      raise "unknown data type: #{_type}." ;
    end
  end
  #--============================================================
  #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
  #--------------------------------------------------------------

end # class SavLog

require 'SavsLogEntry.rb' ;

require 'SavsBusStopTable.rb' ;

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
    TestData0 = "../2018.1030.fromDoCoMo/delogA-10-05.csv" ;
    TestData1 = "../2018.1120.fromDoCoMo/delogB.10-30.csv" ;
    TestData = TestData1 ;

    TestFilePat0 = "../2018.1030.fromDoCoMo/delog*.csv" ;
    TestFilePat1 = "../2018.*/delog*.csv" ;
    TestFilePat = TestFilePat1 ;

    TestAllJson = "../Summary/delog.all.json" ;
    TestPlotFreqBase = "../Summary/freqTable" ;
    TestPlotFreqBaseFactored = "../Summary/freqFactor" ;
    TestPlotProbBase = "../Summary/probTable" ;
    TestPlotProbBaseFactored = "../Summary/probFactor" ;
    TestPlotProbBaseMixture = "../Summary/probMixture" ;

    TestPlotDistOfHourlyProbs = "../Summary/distHourlyProb" ;

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
    ## 1ファイルの読み込み。
    def test_a
      slog = SavsLog.new() ;
      slog.scanCsv(TestData) ;

#      puts slog.toJsonString(true) ;
      puts slog.toJsonString(:line) ;
    end

    #----------------------------------------------------
    #++
    ## 1 directory の読み込み
    def test_b
      Dir.glob(TestFilePat){|file|
        p [:begin, file] ;
        slog = SavsLog.new() ;
        slog.scanCsv(file) ;

#        puts slog.toJsonString(true) ;
        puts slog.toJsonString(:line) ;
        p [:done, file] ;
      }
    end

    #----------------------------------------------------
    #++
    ## 
    def test_c
      totalLog = SavsLog.new() ;
      totalLog.scanCsvGlob(TestFilePat1) ;
      p [:totalSize, totalLog.size] ;
    end

    #----------------------------------------------------
    #++
    ## 
    def test_d
      slog = SavsLog.new() ;
      slog.scanJsonFile(TestAllJson) ;
#      pp slog ;
      p [:pick, slog.entryList.map{|entry|
           entry.getPickUpBusStop().order}] ;
      p [:drop, slog.entryList.map{|entry|
           entry.getDropOffBusStop().order}] ;
      p [:size, slog.size] ;
    end

    #----------------------------------------------------
    #++
    ## 
    def test_e
      slog = SavsLog.new() ;
      slog.scanJsonFile(TestAllJson) ;
      slog.buildFreqTables() ;

#      pp slog.freqTable ;
      p slog.freqTablePickUp ;
      p slog.freqTableDropOff ;
      slog.dumpFreqTableToCsv("/home/noda/Desktop/foo.csv") ;
    end
    
    #----------------------------------------------------
    #++
    ## 
    def test_f
      slog = SavsLog.new() ;
      slog.scanJsonFile(TestAllJson) ;
      slog.buildFreqTables() ;
      slog.calcProbTableFromFreq();

      slog.plotFreqTable(TestPlotFreqBase) ;
      slog.plotFreqFactored(TestPlotFreqBaseFactored) ;
      slog.plotProbTable(TestPlotProbBase) ;
      slog.plotProbFactored(TestPlotProbBaseFactored) ;
    end

    #----------------------------------------------------
    #++
    ## 
    def test_g
      slog = SavsLog.new() ;
      slog.scanJsonFile(TestAllJson) ;
      slog.buildFreqTables() ;
      slog.calcProbTableFromFreq();

      fprob = slog.probTable.dup().dropSingular() ;

      slog.plotGeneric("/home/noda/Desktop/foo0", {:title=>"test_g(0)"}){|i,j|
        fprob.getProb(i,j) ;
      }
      slog.plotGeneric("/home/noda/Desktop/foo1", {:title=>"test_g(1)"}){|i,j|
        fprob.calcProbFactored(i,j) ;
      }
    end

    #----------------------------------------------------
    #++
    ## 
    def test_h
      slog = SavsLog.new() ;
      slog.scanJsonFile(TestAllJson) ;
      slog.buildFreqTables() ;
      slog.calcProbTableFromFreq();

      prob0 = slog.probTable ;
      prob1 = prob0.dup().dropSingular() ;

      p [:div0, prob0.calcKLDivergenceTo(prob0)] ;
      p [:div1, prob0.calcKLDivergenceTo(prob1)] ;
      p [:div1_, prob1.calcKLDivergenceTo(prob0)] ;

      topNDiff = prob0.findTopNDiff(5,prob1) ;
      p [:topN, topNDiff] ;

      prob2 =prob1.dup() ;
      prob2.adjustSingularToward(3, prob0) ;
      p [:div2, prob0.calcKLDivergenceTo(prob2)] ;

      slog.plotGeneric("/home/noda/Desktop/foo2", {:title=>"test_h(2)"}){|i,j|
        prob2.getProb(i,j) ;
      }
      
    end

    #----------------------------------------------------
    #++
    ## 
    def test_i
      slog = SavsLog.new() ;
      slog.scanJsonFile(TestAllJson) ;
      slog.buildFreqTables() ;
      slog.calcProbTableFromFreq();

      slog.calcMixtureProb(5) ;
      
      slog.plotProbTable(TestPlotProbBase) ;
      slog.plotProbFactored(TestPlotProbBaseFactored) ;
      slog.plotProbMixture(TestPlotProbBaseMixture) ;
    end

    #----------------------------------------------------
    #++
    ## 
    def test_j
      k = 5 ;
      suffixK = "%02d" % k ;
      slog = SavsLog.new({:name => "whole"}) ;
      slog.scanJsonFile(TestAllJson) ;
      slog.buildFreqTables() ;
      slog.calcProbTableFromFreq();
      slog.calcMixtureProb(k) ;
      
      slog.plotProbTable(TestPlotProbBase) ;
      slog.plotProbMixture(TestPlotProbBaseMixture + suffixK) ;

      slogWeekday = SavsLog.new({:name => "weekday"}) ;
      slogWeekday.filterByDayTypeFrom(slog, :weekday) ;
      slogWeekday.buildFreqTables() ;
      slogWeekday.calcProbTableFromFreq();
      slogWeekday.calcMixtureProb(k) ;
      
      slogWeekday.plotProbTable(TestPlotProbBase + "_weekday") ;
      slogWeekday.plotProbMixture(TestPlotProbBaseMixture + suffixK + "_weekday") ;

      slogHoliday = SavsLog.new({:name => "holiday"}) ;
      slogHoliday.filterByDayTypeFrom(slog, :holiday) ;
      slogHoliday.buildFreqTables() ;
      slogHoliday.calcProbTableFromFreq();
      slogHoliday.calcMixtureProb(k) ;
      
      slogHoliday.plotProbTable(TestPlotProbBase + "_holiday") ;
      slogHoliday.plotProbMixture(TestPlotProbBaseMixture + suffixK + "_holiday") ;
      
    end

    #----------------------------------------------------
    #++
    ## 
    def test_k
      k = 5 ;
      slog = SavsLog.new({:name => "whole"}) ;
      slog.scanJsonFile(TestAllJson) ;
      slog.procAll(k) ;

      slogHours = {} ;
      SavsLog::WorkHourList.each{|hour|
        subLog = slog.genFilteredSavsLogByHour(hour) ;
        slogHours[hour] = subLog ;
      }

      conf = {:pathBase => TestPlotDistOfHourlyProbs,
              :title => "distances between hourly prob. table",
                   :resolution => [25,25],
#                   :resolution => [50,50],              
                   :approxMode => :hann,
                   :xlabel => "hour X",
                   :ylabel => "hour Y",
                   :zlabel => "dist.",
#                   :logscale => :z,
                   :logscale => nil,
                   :contour => true,
#                   :contour => false,                   
                   :noztics => true,
                   :view => [0, 359.9999],
#                   :view => [30, 60],
                   :tgif => true,
#                   :tgif => false,
                   nil => nil} ;

      Gnuplot::directDgrid3dPlot(conf) {|gplot|
#        gplot.command("set palette rgbformulae 22,13,-31") ;
        gplot.command("set palette grey") ;        
        gplot.command("set cbrange [2.000:6.000]") ;
        gplot.command("set xrange [9:20]") ;
        gplot.command("set yrange [9:20]") ;
        SavsLog::WorkHourList.each{|x|
          SavsLog::WorkHourList.each{|y|
            next if(x==y) ;
            probTableX = slogHours[x].probTable ;
            probTableY = slogHours[y].probTable ;
            dist = probTableX.calcKLDivergenceTo(probTableY) ;
            p [x,y,dist] ;
            value = dist ;
#            value = 1.0 / (dist * dist + 1.0) ;
#            value = Math.log(dist + 1.0) ;
#            value = 1.0 / (dist + 1.0) ;
            gplot.dpDgrid3dPlot(x,y,value) ;
          }
        }
      }
    end
    
  end # class TC_Foo < Test::Unit::TestCase
end # if($0 == __FILE__)
