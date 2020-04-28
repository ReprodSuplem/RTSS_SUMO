#! /usr/bin/env ruby
# coding: utf-8
## -*- Mode: ruby -*-
########################################################################
##Header:
##Title: Multiple Regression Analysis (重回帰分析)
##EndHeader:
########################################################################

$LOAD_PATH.push("~/lib/ruby") ;
require 'LinearAlgebra/Matrix.rb'

##======================================================================
module Stat

  ##============================================================
  class RegAnalysis
    ##::::::::::::::::::::::::::::::::::::::::::::::::::
    ##@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    attr_accessor :count ;
    attr_accessor :dimX ;
    attr_accessor :dimY ;
    attr_accessor :sumX ;
    attr_accessor :sumY ;
    attr_accessor :sumXX ;
    attr_accessor :sumYX ;

    ##--------------------------------------------------
    def initialize(dimY, dimX) ;
      setup(dimY, dimX) ;
    end

    ##--------------------------------------------------
    def setup(dimY, dimX) ;
      @dimY = dimY ;
      @dimX = dimX ;
      @count = 0 ;
      @sumX = LA::Matrix.new(@dimX,1, 0.0) ;
      @sumY = LA::Matrix.new(@dimY,1, 0.0) ;
      @sumXX = LA::Matrix.new(@dimX, @dimX, 0.0) ;
      @sumYX = LA::Matrix.new(@dimY, @dimX, 0.0) ;
    end

    ##--------------------------------------------------
    def pushData(y, x)
      (0...@dimY).each{|i|
        yVal = accessVector(y,i) ;
        @sumY[i,0] += yVal ;
        (0...@dimX).each{|j|
          @sumYX[i,j]  += yVal * accessVector(x, j) ;
        }
      }
      (0...@dimX).each{|i|
        xVal = accessVector(x,i) ;
        @sumX[i,0] += xVal ;
        (0...@dimX).each{|j|
          @sumXX[i,j] += xVal * accessVector(x, j) ;
        }
      }
      countUp() ;
    end

    ##--------------------------------------------------
    def countUp()
      resetAve() ;
      @count += 1 ;
    end

    ##--------------------------------------------------
    def accessVector(v,i)
      if(v.is_a?(Array)) then
        return v[i] ;
      elsif(v.is_a?(LA::Matrix)) then
        return v[i,0] ;
      end
    end

    ##--------------------------------------------------
    def resetAve()
      @aveX = nil ;
      @aveY = nil ;
      @aveXX = nil ;
      @aveYX = nil ;
      @covYX = nil ;
      @covXX = nil ;
      @coefficient = nil ;
      @bias = nil ;
    end

    ##--------------------------------------------------
    def normalizeFactor()
      (1.0 / @count.to_f)
    end

    ##--------------------------------------------------
    def aveX()
      @aveX = @sumX.mul(normalizeFactor()) if(@aveX.nil?) ;
      @aveX ;
    end

    ##--------------------------------------------------
    def aveY()
      @aveY = @sumY.mul(normalizeFactor()) if(@aveY.nil?) ;
      @aveY ;
    end

    ##--------------------------------------------------
    def aveXX()
      @aveXX = @sumXX.mul(normalizeFactor()) if(@aveXX.nil?) ;
      @aveXX ;
    end

    ##--------------------------------------------------
    def aveYX()
      @aveYX = @sumYX.mul(normalizeFactor()) if(@aveYX.nil?) ;
      @aveYX ;
    end

    ##--------------------------------------------------
    def covYX()
      @covYX = aveYX().sub(aveY().mul(aveX().transpose())) if(@covYX.nil?) ;
      @covYX ;
    end

    ##--------------------------------------------------
    def covXX()
      @covXX = aveXX().sub(aveX().mul(aveX().transpose())) if (@covXX.nil?) ;
      @covXX ;
    end

    ##--------------------------------------------------
    def coefficient()
      @coefficient = covYX().mul(covXX().inverse()) if(@coefficient.nil?) ;
      @coefficient ;
    end

    ##--------------------------------------------------
    def bias()
      @bias = aveY().sub(coefficient().mul(aveX())) if(@bias.nil?) ;
      @bias ;
    end

    ##--------------------------------------------------
    def analyzable?()
      begin
        bias() ;
        return true ;
      rescue LA::Matrix::SingularMatrixException => ex then
        return false ;
      end
    end

  end ## class RegAnalysis

  ##============================================================
  class RegAnalysisEMA < RegAnalysis
    ##::::::::::::::::::::::::::::::::::::::::::::::::::
    DefaultAlpha = 0.1 ;
    ##@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    attr_accessor :alphaX ;
    attr_accessor :alphaY ;

    ##--------------------------------------------------
    def initialize(dimY, dimX, alphaY = DefaultAlpha, alphaX = DefaultAlpha) 
      setup(dimY, dimX, alphaY, alphaX) ;
    end

    ##--------------------------------------------------
    def setup(dimY, dimX, alphaY, alphaX) ;
      super(dimY, dimX) ;
      @alphaY = (alphaY.is_a?(Array) ? alphaY : Array.new(dimY, alphaY)) ;
      @alphaX = (alphaX.is_a?(Array) ? alphaX : Array.new(dimX, alphaX)) ;
    end

    ##--------------------------------------------------
    def normalizeFactor()
      1.0 ;
    end

    ##--------------------------------------------------
    def updateByEma(current, newValue, a)
      (1.0 - a) * current + a * newValue ;
    end

    ##--------------------------------------------------
    def pushData(y, x)
      if(@count == 0) then # first case
        super(y, x) ;
      else
        (0...@dimY).each{|i|
          yVal = accessVector(y,i) ;
          @sumY[i,0] = updateByEma(@sumY[i,0], yVal, @alphaY[i]) ;
          (0...@dimX).each{|j|
            @sumYX[i,j]  = updateByEma(@sumYX[i,j], yVal * accessVector(x, j),
                                       Math::sqrt(@alphaY[i] * @alphaX[j])) ;
          }
        }
        (0...@dimX).each{|i|
          xVal = accessVector(x,i) ;
          @sumX[i,0] = updateByEma(@sumX[i,0], xVal, @alphaX[i]) ;
          (0...@dimX).each{|j|
            @sumXX[i,j] = updateByEma(@sumXX[i,j], xVal * accessVector(x, j),
                                      Math::sqrt(@alphaX[i] * @alphaX[j])) ;
          }
          countUp() ;
        }
      end
    end ## class RegAnalysisEMA

  end

end ## module Stat

########################################################################
########################################################################
########################################################################
if(__FILE__ == $0) then
  require 'test/unit'

  ##============================================================
  class TC_RegAnalysis < Test::Unit::TestCase

    ##----------------------------------------
    def setup
      puts ('*' * 5 ) + ' ' + [:run, name].inspect + ' ' + ('*' * 5) ;
      super
    end

    ##----------------------------------------
    def test_a()
      ra = Stat::RegAnalysis.new(2,3) ;

      distX = Stat::Uniform.new(-10.0, 10.0)
      distY = Stat::Uniform.new(-1.0, 1.0) ;
      y = Array.new(2) ;
      x = Array.new(3) ;
      n = 1000 ;

      (0...n).each{|k|
        (0..3).each{|j|
          x[j] = distX.value() ;
        }
        y[0] = x[0] + 2 * x[1] + 0.5 + distY.value();
        y[1] = x[0] + x[1] + x[2] - 0.2 + distY.value();

        ra.pushData(y, x) ;
      }

      p ra ;
      p ra.coefficient() ;
      p ra.bias() ;
    end

    ##----------------------------------------
    def test_b()
      ra = Stat::RegAnalysisEMA.new(2,3,0.01) ;
#      ra = Stat::RegAnalysis.new(2,3) ;

      distX = Stat::Uniform.new(-10.0, 10.0)
      distY = Stat::Uniform.new(-0.1, 0.1) ;
      y = Array.new(2) ;
      x = Array.new(3) ;
      n = 100 ;

      (0...n).each{|k|
        ang = k/100.0 ;
        (0..3).each{|j|
          x[j] = distX.value() ;
        }
        y[0] = x[0] + 2 * x[1] + distY.value() + Math::cos(ang);
        y[1] = Math::sin(ang) * x[0] + x[1] + x[2] - 0.2 + distY.value();

        ra.pushData(y, x) ;

        if(k > 2) then
          p [k, ang, Math::sin(ang), Math::cos(ang)] ;
          p ra.coefficient() ;
          p ra.bias() ;
        end
      }

    end

  end ## class TC_RegAnalysis
end

