#! /usr/bin/env ruby
## -*- Mode: Ruby -*-
##Header:
##Title: S-expression utilities
##Author: Anonymous3
##Type: class definition
##Date: 2004/12/01
##EndHeader:

#require 'net/http' ;
require 'tempfile' ;

##======================================================================
## class Cons
##----------------------------------------------------------------------

class NilClass
  def cons?
    return false
  end
end

class Cons
  attr :car, true ;
  attr :cdr, true ;

  def initialize(car=NIL, cdr=NIL)
    @car = Sexp::ensure(car) ;
    @cdr = Sexp::ensure(cdr) ;
  end
end

##======================================================================
## class Sexp
##----------------------------------------------------------------------

class Sexp 

  ##--------------------------------------------------
  ## Constant

  TagNil	= :tagNil ;
  TagCons	= :tagCons ;
  TagSymbol	= :tagSymbol ;

  ##--------------------------------------------------
  ## attribute

  attr :tag, true ;
  attr :value, true ;

  ##--------------------------------------------------
  ## initialize

  def initialize(value=NIL)
    @value = value ;
    if(value == NIL) then
      @tag = TagNil
    elsif(value.instance_of?(Cons)) then
      @tag = TagCons ;
    else
      @tag = TagSymbol ;
    end
  end

  ##--------------------------------------------------
  ## symbol mode
  def useSymbol?()
    Sexp.useSymbol?()
  end

  ##--------------------------------------------------
  ## tag check

  def cons?()
    return @tag == TagCons ;
  end

  def nil?()
    return @tag == TagNil ;
  end

  def atom?()
    return (@tag == TagNil || @tag == TagSymbol) ;
  end

  ##--------------------------------------------------
  ## equal

  def eq?(sexp)
    return @tag == sexp.tag && @value == sexp.value ;
  end

  def equal?(sexp)
    if(eq?(sexp)) then
      return TRUE ;
    elsif( cons?() && sexp.cons?()) then
      return car().equal?(sexp.car()) && cdr().equal?(sexp.cdr()) ;
    else
      return FALSE ;
    end
  end

  ##--------------------------------------------------
  ## equal to symbol, int, ..

  def eqValue?(value)
    return atom? && @value == value ;
  end

  ##--------------------------------------------------
  ## car/cdr

  def car()
    return @value.car if (cons?()) ;
    return Sexp::nil() ;
  end

  def cdr()
    return @value.cdr if (cons?()) ;
    return Sexp::nil() ;
  end

  ##--------------------------------------------------
  ## rplaca/rplacd

  def rplaca(carval)
    if(cons?()) then
      @value.car = carval ; return TRUE ;
    else
      return FALSE ;
    end
  end

  def rplacd(cdrval)
    if(cons?()) then
      @value.cdr = cdrval ; return TRUE ;
    else
      return FALSE ;
    end
  end

  ##--------------------------------------------------
  ## length

  def length()
    return 0 if (atom?()) ;
    return 1 + cdr().length() ;
  end

  ##--------------------------------------------------
  ## nthcdr

  def nthcdr(n)
    if(n == 0) then
      return self ;
    elsif(cons?()) then
      return cdr().nthcdr(n-1) ;
    else
      return Sexp::nil() ;
    end
  end

  ##--------------------------------------------------
  ## nth

  def nth(n)
    s = nthcdr(n) ;
    return s.car() ;
  end

  ##--------------------------------------------------
  ## first, second ...

  def first()
    return car() ;
  end

  def second()
    return cdr().car() ;
  end

  def third()
    return cdr().cdr().car() ;
  end

  ##--------------------------------------------------
  ## caar cadr cdar ...

  def caar()
    return car().car() ;
  end

  def cadr()
    return cdr().car() ;
  end

  def cdar() 
    return car().cdr() ;
  end

  def cddr()
    return cdr().cdr() ;
  end

  def caddr()
    return cdr().cdr().car() ;
  end

  ##--------------------------------------------------
  ## rest & last

  def rest()
    return cdr();
  end

  def lastCons()
    if(cons?) then
      r = self ;
      while(r.cdr().cons?) do
	r = r.cdr() ;
      end
      return r ;
    else
      return self ;
    end
  end

  def last()
    return lastCons() ;
  end

  def lastItem()
    return lastCons().car() ;
  end

  ##--------------------------------------------------
  ## each

  def each(&block)
    list = self ;
    while(list.cons?()) 
      elm = list.car() ;
      list = list.cdr() ;
      block.call(elm) ;
    end
  end

  alias map each ;

  ##--------------------------------------------------
  ## member

  def member(elm)
    if(!cons?()) then
      return Sexp::nil() ;
    else
      elm = Sexp::ensure(elm) ;
      if(car().equal?(elm)) then
	return self ;
      else
	return cdr().member(elm) ;
      end
    end
  end

  ##--------------------------------------------------
  ## nconc()
  
  def nconc(newTail)
    lastOne = lastCons() ;
    lastOne.rplacd(newTail) ;
    return self ;
  end

  ##--------------------------------------------------
  ## append()
  
  def append(newTail)
    selfCopy = copy() ;
    return selfCopy.nconc(newTail) ;
  end

  ##--------------------------------------------------
  ## addLast()
  
  def addLast(last)
    return nconc(Sexp::list(last)) ;
  end

  ##--------------------------------------------------
  ## reverse()
  
  def reverse()
    return reverseBody(Sexp::nil) ;
  end

  def reverseBody(stack)
    if(nil?()) then
      return stack ;
    else
      cdr().reverseBody(Sexp::cons(car(), stack)) ;
    end
  end

  ##--------------------------------------------------
  ## copy()
  
  def copy()
    top = Sexp::cons(Sexp::nil,Sexp::nil) ;
    last = top ;
    current = self ;
    while(current.cons?())
      newCell = Sexp::cons(current.car(), Sexp::nil) ;
      last.rplacd(newCell) ;
      last = newCell ;
      current = current.cdr() ;
    end
    last.rplacd(current) ;

    return top.cdr() ;
  end

  ##--------------------------------------------------
  ## assoc

  def assoc(key)
    if(!cons?()) then
      return Sexp::nil() ;
    else
      key = Sexp::ensure(key) ;
      entry = car() ;
      if(entry.cons?() && entry.car().equal?(key)) then
	return entry ;
      else
	return cdr().assoc(key) ;
      end
    end
  end

  ##--------------------------------------------------
  ## assoc & cdr

  def assocCdr(key)
    return assoc(key).cdr() ;
  end

  ##--------------------------------------------------
  ## assoc & cdr

  def assocVal(key)
    return assocCdr(key).car() ;
  end

  ##--------------------------------------------------
  ## assoc by Path
  ## path should be an array of keys or index of list
  ## If the key is a string or symbol, do assoc.
  ## If the key is an integer, do nthcdr.
  ## Finally return cdar of the result.

  def assocValByPath(path)
    list = self ;
    path.each{|key|
      if(key.is_a?(Integer))
        list = list.nthcdr(key) ;
      else
        list = list.assoc(key) ;
      end
    }
    return list.cdr().car() ;
  end

  ##--------------------------------------------------
  ## to_a : convert list to array
  ##     if sexp is atom, then return singleton array
  ##     if sexp is nil, then return zero length array

  def to_a()
    r = Array::new() ;
    s = self ;
    while(s.cons?)
      r.push(s.car()) ;
      s = s.cdr() ;
    end
    if(!s.nil?)
      r.push(s) ;
    end

    return r ;
  end

  ##--------------------------------------------------
  ## strlen

  def strlen()
    l = 0 ;
    if(nil?()) then
      l = 2 ;
    elsif(atom?()) then
      if(value.is_a?(Integer))
        if(value > 0) then
          l = (Math::log(value)/Math::log(10)).to_i + 1 ;
        elsif(value < 0) then
          l = (Math::log(-value)/Math::log(10)).to_i + 2 ;
        else ## zero
          l = 1 ;
        end
      elsif(value.is_a?(Float))
#        l = 21 ;
        l = value.to_s.length ;
      else
        l = value.to_s.length ;
      end
    else ## cons case
      s = self ;
      while(s.cons?())
        l += 1 + s.car().strlen() ;
        if(s.cdr().nil?())
          l += 1 ;
        elsif(s.cdr().atom?())
          l += 4 + s.cdr().strlen() ;
        end
        s = s.cdr() ;
      end
    end
    return l ;
  end

  ##--------------------------------------------------
  ## rest strlen 
  ## calculate rest length in len when the sexp write
  ## if overflow, it return negative value

  def restStrlen(len)
    if(atom?()) then
      return len - strlen() ;
    else ## cons case
      l = len
      s = self ;
      while(s.cons?())
        l = s.car().restStrlen(l-1) ; ## -1 is first paren or space
        return l if (l < 0) ;

        if(s.cdr().nil?())
          l -= 1 ; ## last paren
        elsif(s.cdr().atom?())
          l = s.cdr().restStrlen(l-4) ; ## dot, spaces, and last paren
        end
        s = s.cdr() ;
      end
      return l ;
    end
  end

  ##--------------------------------------------------
  ## prity printer

  def pprint(strm = $stdout, newlinep = true, maxcol = Sexp::maxcol)
    pprintBody(strm, "", newlinep, maxcol)
  end

  def pprintBody(strm, indent, newlinep, maxcol)
    if(atom?())
      strm << self.to_s() ;
    else
      if(restStrlen(maxcol) < 0)
        newIndent = indent + " " ;
        separator = "\n" + newIndent ;
      else
        separator = " " ;
      end
      s = self ;
      while(s.cons?())
        if(s == self)
          strm << "("
        else
          strm << separator ;
        end
        s.car().pprintBody(strm, newIndent, false, maxcol - 1)
        s = s.cdr() ;
      end
      if(!s.nil?())
        strm << " . " ;
        s.pprintBody(strm, newIndent, false, maxcol - 1)
      end
      strm << ")" ;
    end

    strm << "\n" if newlinep ;
  end

  ##--------------------------------------------------
  ## to_s

  def to_s()
    r = "" ;
    if(nil?()) then
      r << "()" ;
    elsif(atom?()) then
      r << value.to_s() ;
    else
      r << "(" ;
      l = self ;
      while(l.cons?()) do
	r << " " if (l != self) ;
	r << l.car().to_s() ;
	l = l.cdr() ;
      end
      if(!l.nil?()) then
	r << " . " ;
	r << l.to_s() ;
      end
      r << ")" ;
    end

    return r ;
  end

  ##--------------------------------------------------
  ## to_i

  def to_i()
    if(atom?()) then
      if(nil?()) then
	return 0 ;
      else
	return value.to_i() ;
      end
    else
      return 0 ;
    end
  end

  ##--------------------------------------------------
  ## to_f

  def to_f()
    if(atom?()) then
      if(nil?()) then
	return 0.0 ;
      else
	return value.to_f() ;
      end
    else
      return 0 ;
    end
  end

  ##--------------------------------------------------
  ## print

  def print(ostr = $stdout, newlinep = false)
    ostr << to_s ;
    ostr << "\n" if newlinep ;
  end

  ##--------------------------------------------------
  ## Sexp::Nil constant

  Nil = Sexp::new(NIL) ;

#   @@dummyreadp = FALSE ;

end

##======================================================================
## Sexp class method
##----------------------------------------------------------------------
      
class << Sexp

  attr :dummyreadp, true ;
  @dummyreadp = FALSE ;

  attr :symbolMode, true ;

  ##--------------------------------------------------
  ## get/set maxcol
  def maxcol()
    @maxcol ;
  end

  def setMaxcol(col)
    @maxcol = col ;
  end

#  Sexp::setMaxcol(75) ;
  Sexp::setMaxcol(79) ;

  ##--------------------------------------------------
  ## EnsureSexp

  def ensure(object)
    if(object.instance_of?(Sexp))
      return object ;
    else
      return new(object) ;
    end
  end

  ##--------------------------------------------------
  ## symbol mode
  def useSymbol?()
    @symbolMode ;
  end

  def useSymbol(flag = true)
    @symbolMode = flag ;
  end

  ##--------------------------------------------------
  ## cons

  def nil
    return Sexp::Nil ;
  end

  ##--------------------------------------------------
  ## cons

  def cons(car,cdr) 
    return new(Cons::new(car,cdr)) ;
  end

  ##--------------------------------------------------
  ## pair (for shortcut of recursive cons)

  def pair(first, second)
    cons(first, cons(second, NIL)) ;
  end

  ##--------------------------------------------------
  ## List

  def list(*elmarray,&block)
    listByArray(elmarray,&block)
  end

  ##--------------------------------------------------
  ## List

  def listByArray(elmarray = NIL,&block)
    r = Sexp::nil() ;
    if(elmarray.instance_of?(Array))
      elmarray.reverse_each {|elm| 
        if(block) then
          newelm = block.call(elm) ;
          r = cons(newelm,r) ;
        else
          r = cons(elm,r) ; 
        end
      } 
    else
      r = cons(elmarray,r) ;
    end
    return r ;
  end

  ##--------------------------------------------------
  ## List from arrayed object
  ## [obj0, obj1, ...] -> (obj0.to_Sexp  obj1.to_Sexp ...)
  
  def mapToList(array, method = :to_Sexp, *args)
    if(array.is_a?(Array)) then
      l = array.map{|obj| 
        ((obj.respond_to?(method)) ? obj.send(method, *args) : obj) ; } ;
    elsif(array.is_a?(Hash)) then
      l = array.keys.map{|key|
        obj = array[key] ;
        s = ((obj.respond_to?(method)) ? obj.send(method, *args) : obj) ;
        Sexp::list(key, s) ; } ;
    else
      obj = l ;
      l = [((obj.respond_to?(method)) ? obj.send(method, *args) : obj)] ;
    end
    return listByArray(l) ;
  end

  ##--------------------------------------------------
  ## paired list from hash
  ## {:a => A, :b => B, ...}  ->   ((:a A) (:b B) ...)

  def pairedListByHash(hash)
    r = Sexp::nil() ;
    hash.keys.sort{|x,y| -(x.to_s <=> y.to_s)}.each{|key|
      value = hash[key] ;
      if(value.is_a?(Hash))
        item = cons(key, pairedListByHash(value)) ;
      elsif(value.is_a?(Array))
        item = list(key,listByArray(value)) ;
      else
        item = list(key,value) ;
      end
      r = cons(item, r) ;
    }
    return r ;
  end

  ##--------------------------------------------------
  ## mapcar

  def mapcar(enumerable, &block)
    dummy = Sexp::cons(Sexp::Nil, Sexp::Nil) ;
    tail = dummy
    enumerable.each{|*args|
      tail.replacd(Sexp::cons(block.call(*args),Sexp::Nil))
      tail = tail.cdr() ;
    }
    return dummy.cdr() ;
  end

  ##--------------------------------------------------
  ## scan

  def scanFile(filename)
    strm = File::open(filename) ;
    r = scanStream(strm) ;
    strm.close() ;
    return r;
  end

  def scanString(str) 
    strm = Tempfile::new("sexpreader") ;
    strm << str ;
    strm.open() ;
    r = scanStream(strm) ;
    strm.close(true) ;
    return r ;
  end

  def scanStream(strm)
    return scanTop(strm) ;
  end

  ##----------------------------------------
  ## skip space and comment

  def skipSpaceComments(strm)
    while(!strm.eof?()) do
      case (c=strm.getc())
      when (?\ ) ,(?\n), (?\t), (?\r)
        next ;
      when (?;)
        strm.gets() ;
      else
        strm.ungetc(c) ;
        return TRUE ;
      end
    end
    return FALSE ;
  end

  ##----------------------------------------
  ## scan top

  def scanTop(strm)
    r = skipSpaceComments(strm) ;
    return FALSE if(!r) ;

    return FALSE if(strm.eof?())  ;

    c=strm.getc() ;

    if(c == (?() ) then
      return scanConsTail(strm) ;
    else
      strm.ungetc(c) ;
      return scanAtom(strm) ;
    end
  end

  ##----------------------------------------
  ## scan atom

  def scanAtom(strm) 
    r = "" if ! @dummyreadp ;
    while(!strm.eof?()) do
      c = strm.getc() ;
      case (c)
      when (?\ ), (?\n), (?\t), (?\r), (?;), (?(), (?))
        strm.ungetc(c) ;
        break ;
      else
        r << c.chr() if ! @dummyreadp ;
      end
    end
    if(@dummyreadp)
      return
    elsif(useSymbol?())
#      return scanAsSymbolAtom(r);
      return Sexp::ensure(scanAsSymbolAtom(r));
    else
      return new(r) ;
    end
  end

  ##----------------------------------------
  ## scan string using symbol mode
  def scanAsSymbolAtom(str)
    if(isQuotedString?(str))
      return stripQuote(str) ;
    elsif(canScanAsNumber?(str))
      return scanAsNumber(str) ;
    else
      return str.intern() ;
    end
  end

  ##----------------------------------------
  ## scan cons tail

  def scanConsTail(strm)
    r = skipSpaceComments(strm) ;
    return FALSE if (!r) ;

    c = strm.getc() ;
    if(c == (?))) then
      return Sexp::nil() ;
    else
      strm.ungetc(c) ;
      car = scanTop(strm) ;
      cdr = scanConsTail(strm) ;
      if(@dummyreadp)
        return
      else
        return cons(car,cdr) ;
      end
    end
  end

  ##----------------------------------------
  ## switch dummyread

  def dummyread(flag)
    @dummyreadp = flag ;
  end

  ##----------------------------------------
  ## check str is quoted string
  def isQuotedString?(str)
    c = str[0] ;
    return (c == ?" || c == ?') ;
  end

  ##----------------------------------------
  ## switch dummyread 
  def stripQuote(str)
    # suppose str is quoted string
    if(str =~ /^[\"\'](.*)[\"\']$/)
      return $1 ;
    else
      str ;
    end
  end

  ##----------------------------------------
  ## check need quote
  def needQuote?(str)
    return str =~ /\s/ ;
  end

  ##----------------------------------------
  ## check str is number string
  def canScanAsNumber?(str)
    return str =~ /^-?[\.0-9]+([eE][-+]?[0-9]+)?$/
  end

  ##----------------------------------------
  ## scan string as number 
  def scanAsNumber(str)
    if(str =~ /^[0-9]*$/)
      return str.to_i ;
    else
      return str.to_f ;
    end
  end
      
end

Sexp::dummyread(FALSE) ;
Sexp::useSymbol(FALSE) ;

##======================================================================
## test
##----------------------------------------------------------------------
if($0 == __FILE__)

  ##--------------------------------------------------
  def test1 ()
    p(Sexp::Nil) ;
    $stdout << Sexp::Nil << "\n";

    x = Sexp::new() ;
    p(x) ;
    $stdout << x << "\n";

    x = Sexp::new(Cons::new()) ;
    p(x) ;
    $stdout << x << "\n" ;

    x = Sexp::cons('a','b') ;
    p(x) ;
    $stdout << x << "\n" ;

    x = Sexp::list() ;
    p(x) ;
    $stdout << x << "\n" ;

    x = Sexp::listByArray([]) ;
    p(x) ;
    $stdout << x << "\n" ;

    x = Sexp::list('a','b','c') ;
    p(x) ;
    $stdout << x << "\n" ;
  end

  ##--------------------------------------------------
  def test2 ()
    p(?a) ;
    p(?\n) ;
    while(c=$stdin.getc)
      p(c) ;
      p(c.chr) ;
    end
  end

  ##--------------------------------------------------
  def test3 ()
    s = Sexp::scanString("(a b ( c d e ) ( ))") ;
    p(s) ;
    print(s) ;
  end

  ##--------------------------------------------------
  def test4 ()
    s = Sexp::scanString("((a 1) (b 2) (c 3) (d 4) (e 5))") ;
    puts(s.assoc("a")) ;
    puts(s.member(Sexp::scanString("(c 3)"))) ;
  end

  ##--------------------------------------------------
  def test5 ()
    s = Sexp::scanString("((a 1) (b 2) (c 3) (d 4) (e 5))") ;

    puts(s) ;
    puts(s.copy()) ;
    puts(s.append(Sexp::scanString("(a b c)")))
    puts(s) ;
    puts(s.nconc(Sexp::scanString("(d e f)")))
    puts(s) ;
  end
  
  ##--------------------------------------------------
  def test6 ()
    ss = Sexp::scanString("((a 1) (b 2) (c 3) (d 4) (e 5))") ;
    s = Sexp::list(ss,ss,ss) ;
    puts(s) ;
  end

  ##--------------------------------------------------
  def test7 ()
    s = Sexp::scanString("((a 1) (b 20) (c 333) (d 4444) (e 55555555))") ;
    puts(s) ;
    puts(s.strlen()) ;
    puts(s.restStrlen(10)) ;

    s = Sexp::scanString("((a 1.0) (b 200) (c 3) (d 4) (e 5))") ;
    puts(s) ;
    puts(s.strlen()) ;
    puts(s.restStrlen(10)) ;
  end

  ##--------------------------------------------------
  def test8 ()
    s = Sexp::scanString("((a 1) (b 2) (c 3) (d 4) (e 5))") ;
    ss = Sexp::list(s,s) ;
    sss = Sexp::list(s,s,s) ;
    ssss = Sexp::list(ss,ss) ;

    s.pprint() ;
    ss.pprint() ;
    sss.pprint() ;
    ssss.pprint() ;
  end

  ##--------------------------------------------------
  def test9 ()
    str = <<_STREND_
(defun get-string (n)
  (let ((point (point))
	(str ""))
    (while (> n 0)
      (setq n (1- n))
      (setq str (concat str (char-to-string (char-after (point)))))
      (forward-char 1))
    (goto-char point)
    str))
_STREND_
    s = Sexp::scanString(str) ;
    s.pprint() ;
  end

  ##--------------------------------------------------
  def test10 ()
    p(Sexp.canScanAsNumber?("12345")) ;
    p(Sexp.canScanAsNumber?("12.345")) ;
    p(Sexp.canScanAsNumber?("-12.345e+10")) ;
    p(Sexp.canScanAsNumber?("-12.345e10")) ;
    p(Sexp.canScanAsNumber?("-12.345e-10")) ;

    p(Sexp.scanAsNumber("12345")) ;
    p(Sexp.scanAsNumber("12.345")) ;
    p(Sexp.scanAsNumber("-12.345e+10")) ;
    p(Sexp.scanAsNumber("-12.345e10")) ;
    p(Sexp.scanAsNumber("-12.345e-10")) ;
  end

  ##--------------------------------------------------
  def test11 ()
    p(Sexp.isQuotedString?("foo")) ;
    p(Sexp.isQuotedString?("\"foo\"")) ;
    p(Sexp.isQuotedString?("\'foo\'")) ;

    p(Sexp.stripQuote("foo")) ;
    p(Sexp.stripQuote("\"foo\"")) ;
    p(Sexp.stripQuote("\'foo\'")) ;
  end

  ##----------------------------------------------------------------------
  # test main

  test1() ;
  #test2() ;
  test3() ;
  test4() ;
  test5() ;
  test6() ;
  test7() ;
  test8() ;
  test9() ;
  test10() ;
  test11() ;

end
##----------------------------------------------------------------------
