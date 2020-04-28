#!/usr/bin/ruby
# -*- coding: UTF-8 -*-

require "stringio"

def wcnfGenNcc(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)

start_time = Time.now();

selfDefnWeightsArray = arg1; # It need be self defined (e.g., [3, 25, 8, ...])

$hardClauseBuffer = String.new();
$hardClauseCounter = 0;

nofBus = arg2;

acceptedSizeArray = arg3;

# This type of array data structure is used to program the Formulae (10, 12 & 13)
allPairsHashArray = arg4;

deadlineArray = arg5;

allAcceptedArray = Array.new();
for i in 0..acceptedSizeArray.size-1
  # in eachAcceptedArray, element := [ 0: drop-off | 1: pick-up ]
  eachAcceptedArray = Array.new(acceptedSizeArray[i], -1); # ncc changed 0 to -1
  if arg8[i] == 0
    for j in 0..eachAcceptedArray.size-1
      if allPairsHashArray[i].has_key?(j)
        eachAcceptedArray[allPairsHashArray[i][j]] = 1;
      end
    end
  elsif acceptedSizeArray[i] == 1
    eachAcceptedArray[0] = 0;
  elsif acceptedSizeArray[i] == 0
    eachAcceptedArray.clear();
  end
  allAcceptedArray.push(eachAcceptedArray);
end

newDemandSize = arg6;

#puts "#{allPairsHashArray}";
for i in 0..allPairsHashArray.size-1
  for j in 0..newDemandSize-1
    allPairsHashArray[i][acceptedSizeArray[i]+1+2*j] = acceptedSizeArray[i]+2*j;
  end
end

yAxisOfGridArray = Array.new();
for i in 0..nofBus-1
  if allAcceptedArray[i].size != 0
    yAxisOfGridArray.push(allAcceptedArray[i] + [1,-1]*newDemandSize); # ncc changed 0 to -1
  else
    yAxisOfGridArray.push([1,-1]*newDemandSize);
  end
end

capacityArray = arg7;

#puts "#{acceptedSizeArray}";
#puts "#{allAcceptedArray}";
#puts "#{yAxisOfGridArray}";
#puts "#{allPairsHashArray}";

# --- Initialization is end here ---

allGridsArray = Array.new();
for i in 0..nofBus-1
  gridArray = Array.new();
  for k in 1..yAxisOfGridArray[i].size
    if i == 0
      eachRowArray = Array(
      1+(k-1)*(yAxisOfGridArray[i].size+1)..
      k*(yAxisOfGridArray[i].size+1));
    else
      eachRowArray = Array(
      1+(k-1)*(yAxisOfGridArray[i].size+1)+
      allGridsArray[i-1][allGridsArray[i-1].size-1][allGridsArray[i-1][allGridsArray[i-1].size-1].size-1]..
      k*(yAxisOfGridArray[i].size+1)+
      allGridsArray[i-1][allGridsArray[i-1].size-1][allGridsArray[i-1][allGridsArray[i-1].size-1].size-1]);
    end
    gridArray.push(eachRowArray);
  end
  allGridsArray.push(gridArray);
end

def atMostOne(varArray)
  for i in 0..varArray.size-1
    for j in i+1..varArray.size-1
      $hardClauseBuffer << "-#{varArray[i]} -#{varArray[j]} 0\n";
      $hardClauseCounter += 1;
    end
  end
end

# For hard constraints (i.e., the Formulae (1..2))
#=begin
for i in 0..allGridsArray.size-1
  for j in 0..acceptedSizeArray[i]-1
    tmpArray = Array.new();
    for k in 0..allGridsArray[i][j].size-1
      $hardClauseBuffer << "#{allGridsArray[i][j][k]} ";
      tmpArray.push(allGridsArray[i][j][k]);
    end
    $hardClauseBuffer << "0\n";
    $hardClauseCounter += 1;
    #atMostOne(tmpArray);
  end
end
#=end

#=begin
for h in 0..2*newDemandSize-1
  tmpArray = Array.new();
  for i in 0..allGridsArray.size-1
    for j in acceptedSizeArray[i]+h..allGridsArray[i].size-1
      for k in 0..allGridsArray[i][j].size-1
        $hardClauseBuffer << "#{allGridsArray[i][j][k]} ";
        tmpArray.push(allGridsArray[i][j][k]);
      end
      break;
    end
  end
  $hardClauseBuffer << "0\n";
  $hardClauseCounter += 1;
  atMostOne(tmpArray);
end
#=end

#=begin
for h in 0..allGridsArray.size-1
  for k in 0..allGridsArray[h][0].size-1
    if (k == 0 && acceptedSizeArray[h] != 0) || 
    (k > 0 && k < acceptedSizeArray[h]+1 && yAxisOfGridArray[h][k-1] == 1)
      # sum = 1
      tmpArray = Array.new();
      for j in 0..allGridsArray[h].size-1
        $hardClauseBuffer << "#{allGridsArray[h][j][k]} ";
        tmpArray.push(allGridsArray[h][j][k]);
      end
      $hardClauseBuffer << "0\n";
      $hardClauseCounter += 1;
      #atMostOne(tmpArray);
    elsif yAxisOfGridArray[h][k-1] != 1 # ncc change '== 0' to '!= 1'
      # sum <= 1
      tmpArray = Array.new();
      for j in 0..allGridsArray[h].size-1
        tmpArray.push(allGridsArray[h][j][k]);
      end
      #atMostOne(tmpArray);
    end
  end
end
#=end

#=begin
for k in 0..2*newDemandSize-1
  tmpArray = Array.new();
  flag = 0;
  for h in 0..allGridsArray.size-1
    if yAxisOfGridArray[h][acceptedSizeArray[h]+k] == 1
      # sum sum = 1
      flag = 1;
      for j in 0..allGridsArray[h].size-1
        $hardClauseBuffer << "#{allGridsArray[h][j][acceptedSizeArray[h]+k+1]} ";
        tmpArray.push(allGridsArray[h][j][acceptedSizeArray[h]+k+1]);
      end
    end
  end
  if flag == 1
    $hardClauseBuffer << "0\n";
    $hardClauseCounter += 1;
    atMostOne(tmpArray);
  end
end
#=end

# For connective network (i.e., the Formulae (3..9))

connectNets = Array.new();
for i in 0..nofBus-1
  eachBusCNet = Array.new();
  for j in 1..yAxisOfGridArray[i].size+1
    if i == 0
      eachRowArray = Array(
      1+(j-1)*(yAxisOfGridArray[i].size+1)..
      j*(yAxisOfGridArray[i].size+1));
    else
      eachRowArray = Array(
      1+(j-1)*(yAxisOfGridArray[i].size+1)+
      connectNets[i-1][connectNets[i-1].size-1][connectNets[i-1][connectNets[i-1].size-1].size-1]..
      j*(yAxisOfGridArray[i].size+1)+
      connectNets[i-1][connectNets[i-1].size-1][connectNets[i-1][connectNets[i-1].size-1].size-1]);
    end
    eachBusCNet.push(eachRowArray);
  end
  connectNets.push(eachBusCNet);
end
# puts "#{connectNets}";

# {var <a,b>}.size == lastIntInAllGridsArray
lastIntInAllGridsArray = allGridsArray[allGridsArray.size-1][allGridsArray[allGridsArray.size-1].size-1][allGridsArray[allGridsArray.size-1][allGridsArray[allGridsArray.size-1].size-1].size-1];

for i in 0..connectNets.size-1
  for j in 0..connectNets[i].size-1
    for k in 0..connectNets[i][j].size-1
      connectNets[i][j][k] += lastIntInAllGridsArray;
    end
  end
end
# puts "#{connectNets}";

## Transition laws (i.e., the Formula (3))
def transLaw(varArray, busIdx, cNets) # varArray.size == 3
  # puts "#{varArray}";
  $hardClauseBuffer << "-#{cNets[busIdx][varArray[1]][varArray[0]]} -#{cNets[busIdx][varArray[2]][varArray[1]]} #{cNets[busIdx][varArray[2]][varArray[0]]} 0\n";
  $hardClauseBuffer << "-#{cNets[busIdx][varArray[2]][varArray[0]]} -#{cNets[busIdx][varArray[1]][varArray[2]]} #{cNets[busIdx][varArray[1]][varArray[0]]} 0\n";
  $hardClauseBuffer << "-#{cNets[busIdx][varArray[0]][varArray[1]]} -#{cNets[busIdx][varArray[2]][varArray[0]]} #{cNets[busIdx][varArray[2]][varArray[1]]} 0\n";
  $hardClauseBuffer << "-#{cNets[busIdx][varArray[2]][varArray[1]]} -#{cNets[busIdx][varArray[0]][varArray[2]]} #{cNets[busIdx][varArray[0]][varArray[1]]} 0\n";
  $hardClauseBuffer << "-#{cNets[busIdx][varArray[0]][varArray[2]]} -#{cNets[busIdx][varArray[1]][varArray[0]]} #{cNets[busIdx][varArray[1]][varArray[2]]} 0\n";
  $hardClauseBuffer << "-#{cNets[busIdx][varArray[1]][varArray[2]]} -#{cNets[busIdx][varArray[0]][varArray[1]]} #{cNets[busIdx][varArray[0]][varArray[2]]} 0\n";
  $hardClauseCounter += 6;
end

## Confluence laws (i.e., the Formula (4))
def confLaw(varArray, busIdx, cNets)
  # puts "#{varArray}";
  $hardClauseBuffer << "-#{cNets[busIdx][varArray[0]][varArray[1]]} -#{cNets[busIdx][varArray[0]][varArray[2]]} #{cNets[busIdx][varArray[2]][varArray[1]]} #{cNets[busIdx][varArray[1]][varArray[2]]} 0\n";
  $hardClauseBuffer << "-#{cNets[busIdx][varArray[1]][varArray[0]]} -#{cNets[busIdx][varArray[1]][varArray[2]]} #{cNets[busIdx][varArray[2]][varArray[0]]} #{cNets[busIdx][varArray[0]][varArray[2]]} 0\n";
  $hardClauseBuffer << "-#{cNets[busIdx][varArray[2]][varArray[0]]} -#{cNets[busIdx][varArray[2]][varArray[1]]} #{cNets[busIdx][varArray[1]][varArray[0]]} #{cNets[busIdx][varArray[0]][varArray[1]]} 0\n";
  $hardClauseCounter += 3;
end

## Ramification Laws (i.e., the Formula (5))
def ramifLaw(varArray, busIdx, cNets)
  # puts "#{varArray}";
  $hardClauseBuffer << "-#{cNets[busIdx][varArray[1]][varArray[0]]} -#{cNets[busIdx][varArray[2]][varArray[0]]} #{cNets[busIdx][varArray[2]][varArray[1]]} #{cNets[busIdx][varArray[1]][varArray[2]]} 0\n";
  $hardClauseBuffer << "-#{cNets[busIdx][varArray[0]][varArray[1]]} -#{cNets[busIdx][varArray[2]][varArray[1]]} #{cNets[busIdx][varArray[2]][varArray[0]]} #{cNets[busIdx][varArray[0]][varArray[2]]} 0\n";
  $hardClauseBuffer << "-#{cNets[busIdx][varArray[0]][varArray[2]]} -#{cNets[busIdx][varArray[1]][varArray[2]]} #{cNets[busIdx][varArray[1]][varArray[0]]} #{cNets[busIdx][varArray[0]][varArray[1]]} 0\n";
  $hardClauseCounter += 3;
end

## Chain constraints (i.e., the Formula (7))
def chainCon(varArray, busIdx, cNets, allGridArr) # varArray.size == 3
  # puts "#{varArray}";
  if varArray[2] != 0
    $hardClauseBuffer << "-#{cNets[busIdx][varArray[1]][varArray[0]]} -#{cNets[busIdx][varArray[2]][varArray[1]]} -#{allGridArr[busIdx][varArray[2]-1][varArray[0]]} 0\n";
    $hardClauseBuffer << "-#{cNets[busIdx][varArray[0]][varArray[1]]} -#{cNets[busIdx][varArray[2]][varArray[0]]} -#{allGridArr[busIdx][varArray[2]-1][varArray[1]]} 0\n";
    $hardClauseCounter += 2;
  end
  if varArray[1] != 0
    $hardClauseBuffer << "-#{cNets[busIdx][varArray[2]][varArray[0]]} -#{cNets[busIdx][varArray[1]][varArray[2]]} -#{allGridArr[busIdx][varArray[1]-1][varArray[0]]} 0\n";
    $hardClauseBuffer << "-#{cNets[busIdx][varArray[0]][varArray[2]]} -#{cNets[busIdx][varArray[1]][varArray[0]]} -#{allGridArr[busIdx][varArray[1]-1][varArray[2]]} 0\n";
    $hardClauseCounter += 2;
  end
  if varArray[0] != 0
    $hardClauseBuffer << "-#{cNets[busIdx][varArray[2]][varArray[1]]} -#{cNets[busIdx][varArray[0]][varArray[2]]} -#{allGridArr[busIdx][varArray[0]-1][varArray[1]]} 0\n";
    $hardClauseBuffer << "-#{cNets[busIdx][varArray[1]][varArray[2]]} -#{cNets[busIdx][varArray[0]][varArray[1]]} -#{allGridArr[busIdx][varArray[0]-1][varArray[2]]} 0\n";
    $hardClauseCounter += 2;
  end
end

## Acyclic constraint (i.e., the Formula (6))
def acyCon(varArray, busIdx, cNets) # varArray.size == 2
  # puts "#{varArray}";
  $hardClauseBuffer << "-#{cNets[busIdx][varArray[1]][varArray[0]]} -#{cNets[busIdx][varArray[0]][varArray[1]]} 0\n";
  $hardClauseCounter += 1;
end

## Connective rule (i.e., the Formula (8))
def connectRule(varArray, busIdx, cNets, allGridArr) # varArray.size == 2
  # puts "#{varArray}";
  if varArray[1] != 0
    $hardClauseBuffer << "-#{allGridArr[busIdx][varArray[1]-1][varArray[0]]} #{cNets[busIdx][varArray[1]][varArray[0]]} 0\n";
    $hardClauseCounter += 1;
    # the nextline connectRule may be unnecessary!
    #$hardClauseBuffer << "#{cNets[busIdx][varArray[1]][varArray[0]]} -#{allGridArr[busIdx][varArray[1]-1][varArray[0]]} 0\n";
    #$hardClauseCounter += 1;
  end
  if varArray[0] != 0
    $hardClauseBuffer << "-#{allGridArr[busIdx][varArray[0]-1][varArray[1]]} #{cNets[busIdx][varArray[0]][varArray[1]]} 0\n";
    $hardClauseCounter += 1;
    # the nextline connectRule may be unnecessary!
    #$hardClauseBuffer << "#{cNets[busIdx][varArray[0]][varArray[1]]} -#{allGridArr[busIdx][varArray[0]-1][varArray[1]]} 0\n";
    #$hardClauseCounter += 1;
  end
end

# Nothing like "chicken or egg" -- pair of PD order constraints (i.e., the Formula (10))
def pairPDOrderCon(busIdx, cNets, acceptSizArr, allPairHashArr)
  allPairHashArr[busIdx].each{ |key, value|
    if key < acceptSizArr[busIdx]
      $hardClauseBuffer << "#{cNets[busIdx][key+1][value+1]} 0\n";
      $hardClauseCounter += 1;
    end
  }
  # 20190208 Anonymous1 [AGAIN!!! bug find!!!] interesting -- not treat for newDemandSiz > 1 yet, need further modification (see index, not '+2*i-1', but simply '+1')
  # 20190109 Anonymous1 [bug find -- did not treat for newDemands] patch as follows:
  newDemandSiz = (cNets[busIdx].size()-acceptSizArr[busIdx]-1)/2;
  for i in 1..newDemandSiz
    $hardClauseBuffer << "-#{cNets[busIdx][acceptSizArr[busIdx]+1][0]} #{cNets[busIdx][acceptSizArr[busIdx]+2*i][acceptSizArr[busIdx]+2*i-1]} 0\n";
    $hardClauseCounter += 1;
  end
end

$lastIntInconnectNets = connectNets[connectNets.size-1][connectNets[connectNets.size-1].size-1][connectNets[connectNets.size-1][connectNets[connectNets.size-1].size-1].size-1];
$auxilaryVarArray = Array.new();
def newAuxilaryVar()
  $auxilaryVarArray.push($lastIntInconnectNets + $auxilaryVarArray.size + 1);
  return $auxilaryVarArray[$auxilaryVarArray.size-1];
end

# *Option: keep the accepted job list order (i.e., the Formula (11))
def keepAcceptedOrder(busIdx, cNets, acceptSizArr)
  for i in 1..acceptSizArr[busIdx]-1
    #$hardClauseBuffer << "#{cNets[busIdx][acceptSizArr[busIdx]+1][0]} #{cNets[busIdx][i+1][i]} 0\n";
    $hardClauseBuffer << "-#{newAuxilaryVar()} #{cNets[busIdx][i+1][i]} 0\n";
    $hardClauseCounter += 1;
  end
end

# Implication rules (i.e., the Formulae (12 & 13))
#=begin
def implcRule(busIdx, cNets, allGridArr, acceptSizArr, allPairHashArr)
  tmpCNetCellID = -1;
  for i in 0..allGridArr[busIdx].size-1
    for j in 0..allGridArr[busIdx][i].size-1
      if i >= acceptSizArr[busIdx] && allPairHashArr[busIdx].has_key?(i)
        $hardClauseBuffer << "-#{allGridArr[busIdx][i][j]} #{cNets[busIdx][allPairHashArr[busIdx][i]+1][0]} 0\n";
        $hardClauseCounter += 1;
        tmpCNetCellID = cNets[busIdx][allPairHashArr[busIdx][i]+1][0];
      elsif i >= acceptSizArr[busIdx]
        $hardClauseBuffer << "-#{allGridArr[busIdx][i][j]} #{cNets[busIdx][i+1][0]} 0\n";
        $hardClauseCounter += 1;
        tmpCNetCellID = cNets[busIdx][i+1][0];
      end
      if j > acceptSizArr[busIdx] && allPairHashArr[busIdx].has_key?(j-1) && tmpCNetCellID != cNets[busIdx][allPairHashArr[busIdx][j-1]+1][0]
        $hardClauseBuffer << "-#{allGridArr[busIdx][i][j]} #{cNets[busIdx][allPairHashArr[busIdx][j-1]+1][0]} 0\n";
        $hardClauseCounter += 1;
      elsif j > acceptSizArr[busIdx] && tmpCNetCellID != cNets[busIdx][j][0]
        $hardClauseBuffer << "-#{allGridArr[busIdx][i][j]} #{cNets[busIdx][j][0]} 0\n";
        $hardClauseCounter += 1;
      end
    end
  end
end
#=end
=begin
def implcRule(busIdx, cNets, allGridArr, acceptSizArr, allPairHashArr)
  tmpCNetCellIDArray = Array.new();
  for i in 0..allGridArr[busIdx].size-1
    for j in 0..allGridArr[busIdx][i].size-1
      if i >= acceptSizArr[busIdx] && allPairHashArr[busIdx].has_key?(i)
        $hardClauseBuffer << "-#{allGridArr[busIdx][i][j]} #{cNets[busIdx][allPairHashArr[busIdx][i]+1][0]} 0\n";
        $hardClauseBuffer << "-#{allGridArr[busIdx][i][j]} #{cNets[busIdx][allPairHashArr[busIdx][i]+2][0]} 0\n";
        $hardClauseCounter += 2;
        tmpCNetCellIDArray.push( cNets[busIdx][allPairHashArr[busIdx][i]+1][0] );
        tmpCNetCellIDArray.push( cNets[busIdx][allPairHashArr[busIdx][i]+2][0] );
      elsif i!=allGridArr[busIdx].size-1 && i >= acceptSizArr[busIdx]
        $hardClauseBuffer << "-#{allGridArr[busIdx][i][j]} #{cNets[busIdx][i+1][0]} 0\n";
        $hardClauseBuffer << "-#{allGridArr[busIdx][i][j]} #{cNets[busIdx][i+2][0]} 0\n";
        $hardClauseCounter += 2;
        tmpCNetCellIDArray.push( cNets[busIdx][i+1][0] );
        tmpCNetCellIDArray.push( cNets[busIdx][i+2][0] );
      end
      if j > acceptSizArr[busIdx] && allPairHashArr[busIdx].has_key?(j-1)
        if !tmpCNetCellIDArray.include?(cNets[busIdx][allPairHashArr[busIdx][j-1]+1][0])
          $hardClauseBuffer << "-#{allGridArr[busIdx][i][j]} #{cNets[busIdx][allPairHashArr[busIdx][j-1]+1][0]} 0\n";
          $hardClauseCounter += 1;
          tmpCNetCellIDArray.push( cNets[busIdx][allPairHashArr[busIdx][j-1]+1][0] );
        end
        if !tmpCNetCellIDArray.include?(cNets[busIdx][allPairHashArr[busIdx][j-1]+2][0])
          $hardClauseBuffer << "-#{allGridArr[busIdx][i][j]} #{cNets[busIdx][allPairHashArr[busIdx][j-1]+2][0]} 0\n";
          $hardClauseCounter += 1;
          tmpCNetCellIDArray.push( cNets[busIdx][allPairHashArr[busIdx][j-1]+2][0] );
        end
      elsif j > acceptSizArr[busIdx]
        if !tmpCNetCellIDArray.include?(cNets[busIdx][j][0])
          $hardClauseBuffer << "-#{allGridArr[busIdx][i][j]} #{cNets[busIdx][j][0]} 0\n";
          $hardClauseCounter += 1;
          tmpCNetCellIDArray.push( cNets[busIdx][j][0] );
        end
        if j!=allGridArr[busIdx][i].size-1 && !tmpCNetCellIDArray.include?(cNets[busIdx][j+1][0])
          $hardClauseBuffer << "-#{allGridArr[busIdx][i][j]} #{cNets[busIdx][j+1][0]} 0\n";
          $hardClauseCounter += 1;
          tmpCNetCellIDArray.push( cNets[busIdx][j+1][0] );
        end
      end
    end
  end
end
=end

combiArray = Array.new();
for i in 0..nofBus-1
  combiArray = Array(0..yAxisOfGridArray[i].size).combination(3).to_a;
  for j in 0..combiArray.size-1
    transLaw(combiArray[j], i, connectNets);
    confLaw(combiArray[j], i, connectNets);
    ramifLaw(combiArray[j], i, connectNets);
    chainCon(combiArray[j], i, connectNets, allGridsArray);
  end
  combiArray = Array(0..yAxisOfGridArray[i].size).combination(2).to_a;
  for j in 0..combiArray.size-1
    acyCon(combiArray[j], i, connectNets);
    connectRule(combiArray[j], i, connectNets, allGridsArray);
  end
  pairPDOrderCon(i, connectNets, acceptedSizeArray, allPairsHashArray);
  if acceptedSizeArray[i] > 0
    keepAcceptedOrder(i, connectNets, acceptedSizeArray);
  end
  #implcRule(i, connectNets, allGridsArray, acceptedSizeArray, allPairsHashArray);
  # puts "the #{i+1}-th bus was over";
end

## Demand monopoly (for only one bus) constraints (i.e., the Formula (9))
#=begin
for i in 0..nofBus-1
  $hardClauseBuffer << "-#{connectNets[i][connectNets[i].size-2][0]} #{connectNets[i][connectNets[i].size-1][connectNets[i].size-2]} 0\n";
  $hardClauseBuffer << "-#{connectNets[i][connectNets[i].size-1][0]} #{connectNets[i][connectNets[i].size-1][connectNets[i].size-2]} 0\n";
  $hardClauseCounter += 2;
end
#=end
#=begin
tmpArray = Array.new();
for i in 0..nofBus-1
  #$hardClauseBuffer << "#{connectNets[i][connectNets[i].size-1][connectNets[i].size-2]} ";
  tmpArray.push(connectNets[i][connectNets[i].size-1][connectNets[i].size-2]);
end
#$hardClauseBuffer << "0\n";
#$hardClauseCounter += 1;
atMostOne(tmpArray);
#=end
### I cannot image what was my intention of the following code (perhaps for monopoly constraints)
=begin
for h in 0..2*newDemandSize-1
  tmpArray = Array.new();
  flag = 0;
  for i in 0..connectNets.size-1
    for j in acceptedSizeArray[i]+1+h..connectNets[i].size-1
      if yAxisOfGridArray[i][j-1] == 1
        flag = 1;
        $hardClauseBuffer << "#{connectNets[i][j][0]} ";
        tmpArray.push(connectNets[i][j][0]);
      end
      break;
    end
  end
  if flag == 1
    $hardClauseBuffer << "0\n";
    $hardClauseCounter += 1;
    atMostOne(tmpArray);
  end
end
for h in 0..2*newDemandSize-1
  tmpArray = Array.new();
  flag = 0;
  for i in 0..connectNets.size-1
    for j in acceptedSizeArray[i]+1+h..connectNets[i].size-1
      if yAxisOfGridArray[i][j-1] == -1
        flag = 1;
        $hardClauseBuffer << "#{connectNets[i][j][0]} ";
        tmpArray.push(connectNets[i][j][0]);
      end
      break;
    end
  end
  if flag == 1
    $hardClauseBuffer << "0\n";
    $hardClauseCounter += 1;
    atMostOne(tmpArray);
  end
end
=end

## Block some variables (i.e., add their corresponding unit clauses)
# For 'allGridsArray':
#=begin
# Those are on the diagonal lines (i.e., the self-cyclic paths -- <x,x>)
for h in 0..allGridsArray.size-1
  for j in 0..allGridsArray[h].size-1
    $hardClauseBuffer << "-#{allGridsArray[h][j][j+1]} 0\n";
    $hardClauseCounter += 1;
  end
end
#=end
#=begin
# Those \textbf{N}s (may be unnecessary? but they are the support clauses)
for h in 0..allGridsArray.size-1
  for j in 0..allGridsArray[h].size-1
    if allPairsHashArray[h].has_key?(j)
      $hardClauseBuffer << "-#{allGridsArray[h][allPairsHashArray[h][j]][j+1]} 0\n";
      $hardClauseCounter += 1;
    end
  end
end
#=end
# Capacity?
for h in 0..allGridsArray.size-1
  for j in 0..allGridsArray[h].size-1
    if acceptedSizeArray[h]-2*(allPairsHashArray[h].size-newDemandSize) >= capacityArray[h]
      if allPairsHashArray[h].has_key?(j)
        $hardClauseBuffer << "-#{allGridsArray[h][allPairsHashArray[h][j]][0]} 0\n";
        $hardClauseCounter += 1;
      end
    end
  end
end

# For 'connectNets':
#=begin
# Those are on the diagonal lines (i.e., the self reachability -- \overrightarrow{x,x})
for i in 0..connectNets.size-1
  for j in 0..connectNets[i].size-1
    $hardClauseBuffer << "-#{connectNets[i][j][j]} 0\n";
    $hardClauseCounter += 1;
  end
end
#=end
#=begin
# Those \textbf{N}s (may be unnecessary? but they are the support clauses)
for i in 0..connectNets.size-1
  for j in 0..connectNets[i].size-1
    if j == 0
      for k in 0..connectNets[i][j].size-1
        $hardClauseBuffer << "-#{connectNets[i][j][k]} 0\n";
        $hardClauseCounter += 1;
      end
    elsif allPairsHashArray[i].has_key?(j-1)
      $hardClauseBuffer << "-#{connectNets[i][allPairsHashArray[i][j-1]+1][j]} 0\n";
      $hardClauseCounter += 1;
    end
  end
end
#=end
#=begin
# Starting points constraint (blocking)
for i in 0..connectNets.size-1
  for j in 0..connectNets[i][0].size-1
    $hardClauseBuffer << "-#{connectNets[i][0][j]} 0\n";
    $hardClauseCounter += 1;
  end
end
#=end

nofVar = $lastIntInconnectNets + $auxilaryVarArray.size;

# 20190206 DO NOT continue using MaxSAT optimization
if nofVar >= 2 * nofBus * (4 * 5) * (4 * 5) # note that the capacity is 4
  puts "Encoding failure";
  return false;
end

$softClauseBuffer = String.new();
$softClauseCounter = 0;
$sumOfWeights = 0;

def randWeightGen(upBound)
  generatedWeight = rand(upBound)+1;
  $sumOfWeights += generatedWeight;
  return generatedWeight;
end

$nofPathArray = Array.new();
tmpNofPath = 0; # sum of all tmpNofPaths should be equal to nofSoftClause (?)
$nofPathArray.push(0);
for i in 0..acceptedSizeArray.size-1
  tmpNofPath += (acceptedSizeArray[i]+2*newDemandSize)*(acceptedSizeArray[i]+2*newDemandSize+1);
  $nofPathArray.push(tmpNofPath);
end

def selfDefnWeightGen(weiArray, busIdx, to, from, yAxisOfGridArray)
  if weiArray.size != $nofPathArray[$nofPathArray.size-1]
    exit!
  else
    weiArrIdx = $nofPathArray[busIdx] + to*(yAxisOfGridArray[busIdx].size+1) + from;
    if weiArray[weiArrIdx] != nil
      return weiArray[weiArrIdx];
    else 
      return 0;
    end
  end
end

threshold = 0; # 0: shift this optional block to "off"
for h in 0..allGridsArray.size-1
  for j in 0..allGridsArray[h].size-1
    for k in 0..allGridsArray[h][j].size-1
      eachWeight = selfDefnWeightGen(selfDefnWeightsArray, h, j, k, yAxisOfGridArray);
      $sumOfWeights += eachWeight;
      $softClauseBuffer << "#{eachWeight} -#{connectNets[h][acceptedSizeArray[h]+1][0]} -#{allGridsArray[h][j][k]} 0\n";
      $softClauseCounter += 1;
      # *Optional block: humanitarian (for driver) rule (i.e., the Formula (15))
      if j == 0 && k == 0 && acceptedSizeArray[h] > 0 # && arg8[h] == 1 # && eachWeight < threshold
        $hardClauseBuffer << "#{allGridsArray[h][j][k]} 0\n";
        $hardClauseCounter += 1;
      end
    end
  end
end

#puts "the number of variables: #{nofVar}";
#puts "the number of hard clauses: #{$hardClauseCounter}";
#puts "the number of soft clauses: #{$softClauseCounter}";

wcnFile = File.new("../../encodedProblem/test.wcnf", "w+");
wcnFile.syswrite("p wcnf #{nofVar} #{$hardClauseCounter+$softClauseCounter} #{$sumOfWeights+1}\n");

#=begin
lineReader = StringIO.new($hardClauseBuffer);
begin
  while lineBuffer = lineReader.readline()
    wcnFile.syswrite("#{$sumOfWeights+1} " + lineBuffer);
  end
rescue EOFError;
end
#=end

wcnFile.syswrite($softClauseBuffer);

$externalityBuffer = String.new();

$externalityBuffer << "nofBus #{nofBus}\n";
$externalityBuffer << "newDemandSize #{newDemandSize}\n";
$externalityBuffer << "acceptedSizeArray #{acceptedSizeArray.join(" ")}\n";
$externalityBuffer << "gridStartIndex";
for x in 0..allGridsArray.size-1
  $externalityBuffer << " #{allGridsArray[x][0][0]}"; 
end
$externalityBuffer << "\n";
$externalityBuffer <<  "deadlineArray #{deadlineArray.join(" ")}\n";
$externalityBuffer <<  "nofCarried";
for x in 0..allAcceptedArray.size-1
  if arg8[x] == 0
    $externalityBuffer <<  " #{acceptedSizeArray[x]-2*(allPairsHashArray[x].size-newDemandSize)}";
  else
    $externalityBuffer <<  " 0";
  end
end
$externalityBuffer << "\n";
$externalityBuffer <<  "pickDropArray";
for x in 0..allAcceptedArray.size-1
  $externalityBuffer <<  " #{yAxisOfGridArray[x].join(" ")}";
end
$externalityBuffer << "\n";
$externalityBuffer << "capacityArray #{capacityArray.join(" ")}\n";
# 20190204 Anonymous1 for dummy
#=begin
tmpHS = Hash.new();
for h in 0..allGridsArray.size-1
  tmpSum = 0;
  for i in 0..allGridsArray[h][0].size-2
    tmpSum += selfDefnWeightGen(selfDefnWeightsArray, h, i, i, yAxisOfGridArray);
  end
  tmpHS.store(h, tmpSum);
end
sortedHSArray = tmpHS.sort_by{ |k,v| v };
$externalityBuffer << "dummyArray";
for h in 0..sortedHSArray.size-1
  for i in 0..allGridsArray[sortedHSArray[h][0]][0].size-2
    $externalityBuffer << " #{allGridsArray[sortedHSArray[h][0]][i][i]-1}";
  end
end
#=end
=begin
tmpHS = Hash.new();
for h in 0..allGridsArray.size-1
  tmpSum = 0;
  for i in 0..allGridsArray[h][0].size-2
    tmpSum += selfDefnWeightsArray[allGridsArray[h][i][i]-1];
  end
  tmpHS.store(h, tmpSum);
end
sortedHSArray = tmpHS.sort_by{ |k,v| v };
$externalityBuffer << "dummyArray";
for h in 0..sortedHSArray.size-1
  $externalityBuffer << " #{allGridsArray[sortedHSArray[h][0]][allGridsArray[sortedHSArray[h][0]].size-1][allGridsArray[sortedHSArray[h][0]].size-1]-1}";
  for i in 0..connectNets[sortedHSArray[h][0]].size-3
    $externalityBuffer << " #{connectNets[sortedHSArray[h][0]][connectNets[sortedHSArray[h][0]].size-1][i]-1}";
  end
end
=end
$externalityBuffer << "\n";
$externalityBuffer << "dummyOrder";
for h in 0..sortedHSArray.size-1
  $externalityBuffer << " #{sortedHSArray[h][0]}";
end
$externalityBuffer << "\n";
$externalityBuffer << "keepAuxVar";
for h in 0..$auxilaryVarArray.size-1
  $externalityBuffer << " #{$auxilaryVarArray[h]-1}";
end
$externalityBuffer << "\n";



exFile = File.new("../../encodedProblem/externality.txt", "w+");
#=begin
lineReader = StringIO.new($externalityBuffer);
begin
  while lineBuffer = lineReader.readline()
    exFile.syswrite(lineBuffer);
  end
rescue EOFError;
end
#=end

puts "MaxSAT encoding complete!";

#=begin
nofMax = 65534;
nofInst = 1;
for i in 2..nofMax+1
  if File.exist?("../../expDir/genrdMaxInst/test_#{nofInst}.wcnf")
    if i == nofMax+1
      exit
    end
    nofInst = i;
  end
end
timeFile = File.new("../../expDir/maxSATime/test_#{nofInst}.time", "w+");
timeFile.syswrite("maxsatEncodingTime #{nofInst} : #{Time.now() - start_time}");
cpWcnf = "cp ../../encodedProblem/test.wcnf ../../expDir/genrdMaxInst/test_#{nofInst}.wcnf";
cpEx = "cp ../../encodedProblem/externality.txt ../../expDir/genrdMaxInst/externality_#{nofInst}.txt";
system(cpWcnf);
system(cpEx);
#=end

return true;

end













