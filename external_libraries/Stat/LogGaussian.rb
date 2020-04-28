#! /usr/bin/env ruby
## -*- mode: ruby -*-
## = Log-Normal (Gaussian) distribution
## Author:: Anonymous3
## Version:: 0.0 2019/01/12 Anonymous3
##
## === History
## * [2019/01/12]: Create This File.
## * [YYYY/MM/DD]: add more
## == Usage
## * ...

def $LOAD_PATH.addIfNeed(path)
  self.unshift(path) if(!self.include?(path)) ;
end

$LOAD_PATH.addIfNeed("~/lib/ruby");
# $LOAD_PATH.addIfNeed(File.dirname(__FILE__));

require 'Stat/Gaussian.rb' ;

module Stat
  #--======================================================================
  #++
  ## Log-Normal (Gaussian) Distribution.
  class LogGaussian < RandomValue
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #++
    ## base gaussian
    attr_accessor :gaussian ;
    ## multiply factor
    attr_accessor :magnify ;

    #--------------------------------------------------------------
    #++
    ## initialize
    ## _mean_:: Mean value for the base Gaussian.
    ## _std_:: standard diviation for the base Gaussian.
    ## _magnify_:: magnification factor.
    def initialize(_mean = 1.0, _std = 1.0, _magnify = 1.0)
      setup(_mean, _std, _magnify) ;
    end

    #--------------------------------------------------------------
    #++
    ## setup parameters
    ## _mean_:: Mean value for the base Gaussian.
    ## _std_:: standard diviation for the base Gaussian.
    ## _magnify_:: magnification factor.
    ## *return*:: self
    def setup(_mean = 0.0, _std = 1.0, _magnify = 1.0)
      @gaussian = Stat::Gaussian.new(_mean, _std) ;
      @magnify = _magnify ;
      return self
    end

    #--------------------------------------------------------------
    #++
    ## density value.
    ## The density function is:
    ##     p(x) = \frac{1}{\sqrt{2 \pi} \sigma x}
    ##            \exp{\frac{-(\log x - \mu)^2}{2 \sigma^2}}.
    ## The max value is at: x = \exp{\mu - \sigma^2}
    ## The average is: |x| = \exp{\mu + (\sigma^2 / 2)}
    ## The median is: X = \exp{\mu}
    ## _x_:: the value
    ## *return*:: dencity
    def density(x)
      if(x <= 0.0) then
        return 0.0 ;
      else
        y = x / @magnify ;
        return ((1.0 / y) * @gaussian.density(Math::log(y)) / @magnify) ;
      end
    end
    
    ##--------------------------------------------------
    def rand()
      return @magnify * Math::exp(@gaussian.rand()) ;
    end

    ##--------------------------------------------------
    def value()
      rand()
    end

    ##--------------------------------------------------
    def to_s()
      ("#LogGaussian[m=%f, s=%f, a=%f]" % [@gaussian.mean, @gaussian.std,
                                           @magnify]) ;
    end

    #--============================================================
    #--------------------------------------------------------------
    ## new instance by the mode (most frequent value) and standard diviation.
    ## _mode_:: the mode value.
    ## _std_:: std value.
    ## *return*:: new instance.
    def self.newByMode(mode, std)
      return self.new(std**2, std, mode) ;
    end
    
    #--============================================================
    #--::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
    #--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    #--------------------------------------------------------------
  end # class LogGaissian

end # module Stat

########################################################################
########################################################################
########################################################################
if($0 == __FILE__) then

  require 'test/unit'
  require 'gnuplot.rb' ;

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
      eps = 1.0e-2 ;
      max = 10.0 ;
      n = (max / eps).to_i ;
      paramList = {
        :a => { :mean => 1.0,
                :std => 1.0,
                :magnify => 1.0 },
        :b => { :mean => 1.0,
                :std => 0.5,
                :magnify => 1.0 },
        :c => { :mean => 1.0,
                :std => 0.5,
                :magnify => 2.0 },
        :d => { :mean => 2.0,
                :std => 0.5,
                :magnify => 1.0 },
      } ;
      distList = {} ;
      paramList.each{|key, param|
        dist = Stat::LogGaussian.new(param[:mean], param[:std],
                                     param[:magnify]) ;
        distList[key] = dist ;
      }
      
      Gnuplot::directMultiPlot(paramList.keys.sort,"","w l") {|gplot|
        distList.each{|key, dist|
          gplot.dmpSetTitle(key, dist.to_s) ;
        }
        (1..n).each{|i|
          x = eps * i ;
          distList.each{|key, dist|
            gplot.dmpXYPlot(key, x, dist.density(x)) ;
          }
        }
      }
    end

    #----------------------------------------------------
    #++
    ## about test_b
    def test_b
      eps = 1.0e-2 ;
      max = 10.0 ;
      n = (max / eps).to_i ;
      paramList = {
        :a => { :mode => 2.0,
                :std => 1.0},
        :b => { :mode => 2.0,
                :std => 2.0},
        :c => { :mode => 2.0,
                :std => 0.5},
        :d => { :mode => 2.0,
                :std => 0.3},
      } ;
      distList = {} ;
      paramList.each{|key, param|
        dist = Stat::LogGaussian.newByMode(param[:mode], param[:std]) ;
        distList[key] = dist ;
      }
      
      Gnuplot::directMultiPlot(paramList.keys.sort,"","w l") {|gplot|
        distList.each{|key, dist|
          gplot.dmpSetTitle(key, paramList[key].inspect) ;
        }
        (1..n).each{|i|
          x = eps * i ;
          distList.each{|key, dist|
            gplot.dmpXYPlot(key, x, dist.density(x)) ;
          }
        }
      }
    end

  end # class TC_Foo < Test::Unit::TestCase
end # if($0 == __FILE__)
