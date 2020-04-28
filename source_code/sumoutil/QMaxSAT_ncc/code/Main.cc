/*****************************************************************************************[Main.cc]
Copyright (c) 2003-2006, Niklas Een, Niklas Sorensson
Copyright (c) 2007-2010, Niklas Sorensson

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
**************************************************************************************************/

#include <errno.h>

#include <signal.h>
#include <zlib.h>

#include "utils/System.h"
//#include "maxsat0.2f-glucose3.0/ParseUtils.h" // koshi 20140210
//#include "qmaxsat2016-g3/ParseUtils.h" // uemura 20161128
#include "ParseUtils.h" // koshi 20170630
#include "utils/Options.h"
//#include "maxsat0.2f-glucose3.0/Dimacs.h" // koshi 20140124
//#include "qmaxsat2016-g3/Dimacs.h" // uemura 20161128
#include "Dimacs.h" // koshi 20170630
#include "core/Solver.h"

#include <stdio.h> // Anonymous1 20181217
#include <stdlib.h> // Anonymous1 20181217
#include <iostream> // Anonymous1 20181218
#include <string> // Anonymous1 20181218
#include <vector> // Anonymous1 20181218
#include <fstream> // Anonymous1 20181221

/* koshi 20140124
using namespace Minisat;
*/
using namespace Glucose;
using namespace std;

/*
  koshi 20140106
  based on minisat2-070721/maxsat0.2e
 */
// koshi 20140106
#define TOTALIZER 128

//=================================================================================================


void printStats(Solver& solver)
{
    double cpu_time = cpuTime();
    double mem_used = memUsedPeak();
    //    double mem_used = 0;
    printf("c restarts              : %"PRIu64"\n", solver.starts);
    printf("c conflicts             : %-12"PRIu64"   (%.0f /sec)\n", solver.conflicts   , solver.conflicts   /cpu_time);
    printf("c decisions             : %-12"PRIu64"   (%4.2f %% random) (%.0f /sec)\n", solver.decisions, (float)solver.rnd_decisions*100 / (float)solver.decisions, solver.decisions   /cpu_time);
    printf("c propagations          : %-12"PRIu64"   (%.0f /sec)\n", solver.propagations, solver.propagations/cpu_time);
    printf("c conflict literals     : %-12"PRIu64"   (%4.2f %% deleted)\n", solver.tot_literals, (solver.max_literals - solver.tot_literals)*100 / (double)solver.max_literals);
    if (mem_used != 0) printf("c Memory used           : %.2f MB\n", mem_used);
    printf("c CPU time              : %g s\n", cpu_time);
}


static Solver* solver;
// Terminate by notifying the solver and back out gracefully. This is mainly to have a test-case
// for this feature of the Solver as it may take longer than an immediate call to '_exit()'.
static void SIGINT_interrupt(int signum) { solver->interrupt(); }

// Note that '_exit()' rather than 'exit()' has to be used. The reason is that 'exit()' calls
// destructors and may cause deadlocks if a malloc/free function happens to be running (these
// functions are guarded by locks for multithreaded use).
static void SIGINT_exit(int signum) {
    printf("\n"); printf("*** INTERRUPTED ***\n");
    if (solver->verbosity > 0){
        printStats(*solver);
        printf("\n"); printf("*** INTERRUPTED ***\n"); }
    _exit(1); }


// koshi 20140106 based on minisat2-070721/maxsat0.2e
// Lit -> mkLit, addClause -> addClause_
// koshi 2013.05.23
long long int sumWeight(vec<long long int>& weights) {
  long long int sum = 0;
  for(int i = 0; i < weights.size(); i++) sum += weights[i];
  return sum;
}



//CyouRyuu (quicksort)
long long int med3(long long int x, long long int y, long long int z) {
	if (x < y) {
		if (y < z) return y; else if (z < x) return x; else return z;
	} else {
		if (z < y) return y; else if (x < z) return x; else return z;
	}
}
void quicksort(long long int a[], int left, int right) {
	if (left < right) {
		int i = left, j = right;
		long long int tmp, pivot = med3(a[i], a[i + (j - i) / 2], a[j]);
		while (1) {
			while (a[i] < pivot) i++;
			while (pivot < a[j]) j--;
			if (i >= j) break;
			tmp = a[i]; a[i] = a[j]; a[j] = tmp;
			i++; j--;
		}
		quicksort(a, left, i - 1);
		quicksort(a, j + 1, right);
	}
}

// Anonymous1 (split)
vector<string> split(const string &s, char delim) {
    vector<string> elems;
    string item;
    for (char ch: s) {
        if (ch == delim) {
            if (!item.empty())
                elems.push_back(item);
            item.clear();
        }
        else {
            item += ch;
        }
    }
    if (!item.empty())
        elems.push_back(item);
    return elems;
}

// Anonymous1 (fromTo: to == allGridsArray[h][0][0][?])
int fromTo(int from, int yAxis, int gap){
	int to;
	if ((from-gap)%(1+yAxis) == 0) to = (from-gap)/(1+yAxis)+gap+1;
	else to = (from-gap)/(1+yAxis)+gap+2;
	return to;
}

// Anonymous1 (chainSorter)
void chainSorter(int from, int yAxis, int gap, vector<int>& chain, vector<bool>& fullIdxArr) {
	int to = fromTo(from, yAxis, gap);
	for (int i=1; i<=yAxis; i++) {
		if (fullIdxArr[(i-1)*(yAxis+1)+to-1]) {
			chain.push_back((i-1)*(yAxis+1)+to);
			chainSorter((i-1)*(yAxis+1)+to, yAxis, gap, chain, fullIdxArr);
			break;
		}
	}
}

/*
  Cardinality Constraints:
  Joost P. Warners, "A linear-time transformation of linear inequalities
  into conjunctive normal form",
  Information Processing Letters 68 (1998) 63-69
 */

// koshi 2013.04.16
void genWarnersHalf(Lit& a, Lit& b, Lit& carry, Lit& sum, int comp,
		       Solver& S, vec<Lit>& lits) {
  // carry
  lits.clear();
  lits.push(~a); lits.push(~b); lits.push(carry);  S.addClause_(lits);
  // sum
  lits.clear();
  lits.push(a); lits.push(~b); lits.push(sum);  S.addClause_(lits);
  lits.clear();
  lits.push(~a); lits.push(b); lits.push(sum);  S.addClause_(lits);
  //
  if (comp == 1 || comp == 2) {
    lits.clear();
    lits.push(carry); lits.push(sum); lits.push(~a); S.addClause_(lits);
    lits.clear();
    lits.push(carry); lits.push(sum); lits.push(~b); S.addClause_(lits);
  }
  if (comp == 2) {
    lits.clear();
    lits.push(~carry); lits.push(~sum); S.addClause_(lits);
    lits.clear();
    lits.push(~carry); lits.push(sum); lits.push(a); S.addClause_(lits);
    lits.clear();
    lits.push(~carry); lits.push(sum); lits.push(b); S.addClause_(lits);
  }
  // koshi 2013.05.31
  if (comp == 10 || comp == 11) { // [Warners 1996]
    // carry
    lits.clear(); lits.push(a); lits.push(~carry); S.addClause_(lits);
    lits.clear(); lits.push(b); lits.push(~carry); S.addClause_(lits);
    // sum
    lits.clear();
    lits.push(~a); lits.push(~b); lits.push(~sum);  S.addClause_(lits);
    lits.clear();
    lits.push(a); lits.push(b); lits.push(~sum);  S.addClause_(lits);
  }
}

// koshi 2013.04.16
void genWarnersFull(Lit& a, Lit& b, Lit& c, Lit& carry, Lit& sum, int comp,
		       Solver& S, vec<Lit>& lits) {
  // carry
  lits.clear();
  lits.push(~a); lits.push(~b); lits.push(carry); S.addClause_(lits);
  lits.clear();
  lits.push(~a); lits.push(~c); lits.push(carry); S.addClause_(lits);
  lits.clear();
  lits.push(~b); lits.push(~c); lits.push(carry); S.addClause_(lits);
  // sum
  lits.clear();
  lits.push(a); lits.push(b); lits.push(~c); lits.push(sum);
  S.addClause_(lits);
  lits.clear();
  lits.push(a); lits.push(~b); lits.push(c); lits.push(sum);
  S.addClause_(lits);
  lits.clear();
  lits.push(~a); lits.push(b); lits.push(c); lits.push(sum);
  S.addClause_(lits);
  lits.clear();
  lits.push(~a); lits.push(~b); lits.push(~c); lits.push(sum);
  S.addClause_(lits);
  if (comp == 1 || comp == 2) {
    lits.clear();
    lits.push(carry); lits.push(sum); lits.push(~a); S.addClause_(lits);
    lits.clear();
    lits.push(carry); lits.push(sum); lits.push(~b); S.addClause_(lits);
    lits.clear();
    lits.push(carry); lits.push(sum); lits.push(~c); S.addClause_(lits);
  }
  if (comp == 2) {
    lits.clear();
    lits.push(~carry); lits.push(~sum); lits.push(a); S.addClause_(lits);
    lits.clear();
    lits.push(~carry); lits.push(~sum); lits.push(b); S.addClause_(lits);
    lits.clear();
    lits.push(~carry); lits.push(~sum); lits.push(c); S.addClause_(lits);
  }
  // koshi 2013.05.31
  if (comp == 10 || comp == 11) {// [Warners 1996]
    // carry
    lits.clear();
    lits.push(a); lits.push(b); lits.push(~carry); S.addClause_(lits);
    lits.clear();
    lits.push(a); lits.push(c); lits.push(~carry); S.addClause_(lits);
    lits.clear();
    lits.push(b); lits.push(c); lits.push(~carry); S.addClause_(lits);
    // sum
    lits.clear();
    lits.push(a); lits.push(b); lits.push(c); lits.push(~sum);
    S.addClause_(lits);
    lits.clear();
    lits.push(~a); lits.push(~b); lits.push(c); lits.push(~sum);
    S.addClause_(lits);
    lits.clear();
    lits.push(~a); lits.push(b); lits.push(~c); lits.push(~sum);
    S.addClause_(lits);
    lits.clear();
    lits.push(a); lits.push(~b); lits.push(~c); lits.push(~sum);
    S.addClause_(lits);
  }
}
/*
#define wbsplit(wL,wR, ws,bs, wsL,bsL, wsR,bsR) \
  wsL.clear(); bsL.clear(); wsR.clear(); bsR.clear(); \
  for(int i = 0; i < ws.size(); i++) { \
    if (wL < wR) { \
      wsL.push(ws[i]); \
      bsL.push(bs[i]); \
      wL += ws[i]; \
    } else { \
      wsR.push(ws[i]); \
      bsR.push(bs[i]); \
      wR += ws[i]; \
    } \
  }
*/
/*
#define wbsplit(half,wL,wR, ws,bs, wsL,bsL, wsR,bsR) \
  wsL.clear(); bsL.clear(); wsR.clear(); bsR.clear(); \
  int ii = 0; \
  for(; ii < ws.size()-1; ii++) { \
    if(wL >= half) break; \
    wsL.push(ws[ii]); \
    bsL.push(bs[ii]); \
    wL += ws[ii]; \
  } \
  for(; ii < ws.size(); ii++) { \
    wsR.push(ws[ii]); \
    bsR.push(bs[ii]); \
    wR += ws[ii]; \
  }
*/
#define wbsplit(half,wL,wR, ws,bs, wsL,bsL, wsR,bsR) \
  wsL.clear(); bsL.clear(); wsR.clear(); bsR.clear(); \
  int ii = 0; \
  int wsSizeHalf = ws.size()/2; \
  for(; ii < wsSizeHalf; ii++) { \
    wsL.push(ws[ii]); \
    bsL.push(bs[ii]); \
    wL += ws[ii]; \
  } \
  for(; ii < ws.size(); ii++) { \
    wsR.push(ws[ii]); \
    bsR.push(bs[ii]); \
    wR += ws[ii]; \
  }


// koshi 2013.03.25
// Parallel counter
// koshi 2013.04.16, 2013.05.23
void genWarners(vec<long long int>& weights, vec<Lit>& blockings,
		long long int max, int k,
		int comp, Solver& S, const Lit zero,
		vec<Lit>& lits, vec<Lit>& linkingVar) {

  linkingVar.clear();
  bool dvar = (comp == 11) ? false : true;

  if (weights.size() == 1) {
    long long int weight = weights[0];
    vec<bool> pn;
    pn.clear();
    while (weight > 0) {
      if (weight%2 == 0) pn.push(false);
      else pn.push(true);
      weight /= 2;
    }
    for(int i = 0; i < pn.size(); i++) {
      if (pn[i]) linkingVar.push(blockings[0]);
      else linkingVar.push(zero);
    }
    pn.clear();
  } else if (weights.size() > 1) {
    long long int weightL = 0; long long int weightR = 0;
    vec<long long int> weightsL, weightsR;
    vec<Lit> blockingsL, blockingsR;
    /*
    weightsL.clear(); weightsR.clear();
    blockingsL.clear(); blockingsR.clear();
    for(int i = 0; i < weights.size(); i++) {
      if (weightL < weightR) {
	weightsL.push(weights[i]);
	blockingsL.push(blockings[i]);
	weightL += weights[i];
      } else {
	weightsR.push(weights[i]);
	blockingsR.push(blockings[i]);
	weightR += weights[i];
      }
    }
    */
    long long int half = max/2;
    wbsplit(half,weightL,weightR, weights,blockings,
	    weightsL,blockingsL, weightsR,blockingsR);

    vec<Lit> alpha;
    vec<Lit> beta;
    Lit sum = mkLit(S.newVar(true,dvar));
    Lit carry = mkLit(S.newVar(true,dvar));
    genWarners(weightsL, blockingsL, weightL,k, comp, S, zero, lits,alpha);
    genWarners(weightsR, blockingsR, weightR,k, comp, S, zero, lits,beta);
    weightsL.clear(); weightsR.clear();
    blockingsL.clear(); blockingsR.clear();

    bool lessthan = (alpha.size() < beta.size());
    vec<Lit> &smalls = lessthan ? alpha : beta;
    vec<Lit> &larges = lessthan ? beta : alpha;
    assert(smalls.size() <= larges.size());

    genWarnersHalf(smalls[0],larges[0], carry,sum, comp, S,lits);
    linkingVar.push(sum);

    int i = 1;
    Lit carryN;
    for(; i < smalls.size(); i++) {
      sum = mkLit(S.newVar(true,dvar));
      carryN = mkLit(S.newVar(true,dvar));
      genWarnersFull(smalls[i],larges[i],carry, carryN,sum, comp, S,lits);
      linkingVar.push(sum);
      carry = carryN;
    }
    for(; i < larges.size(); i++) {
      sum = mkLit(S.newVar(true,dvar));
      carryN = mkLit(S.newVar(true,dvar));
      genWarnersHalf(larges[i],carry, carryN,sum, comp, S,lits);
      linkingVar.push(sum);
      carry = carryN;
    }
    linkingVar.push(carry);
    alpha.clear();beta.clear();
  }
  int lsize = linkingVar.size();
  for (int i = k; i < lsize; i++) { // koshi 2013.05.27
    //    printf("shrink: k = %d, lsize = %d\n",k,lsize);
    lits.clear();
    lits.push(~linkingVar[i]);
    S.addClause_(lits);
  }
  for (int i = k; i < lsize; i++) linkingVar.shrink(1); // koshi 2013.05.27
}

// koshi 2013.05.23
void wbSort(vec<long long int>& weights, vec<Lit>& blockings,
	    vec<long long int>& sweights, vec<Lit>& sblockings) {
  sweights.clear(); sblockings.clear();
  /*
  for(int i = 0; i < weights.size(); i++) {
    int maxi = i;
    for(int j = i+1; j < weights.size(); j++) {
      if(weights[maxi] < weights[j]) maxi = j;
    }
    if (maxi != i) { // swap
      long long int tweight = weights[maxi];
      Lit tblocking = blockings[maxi];
      weights[maxi] = weights[i];
      blockings[maxi] = blockings[i];
      weights[i] = tweight;
      blockings[i] = tblocking;
    }
  }
  */
  for(int i = 0; i < weights.size(); i++) {
    sweights.push(weights[i]);
    sblockings.push(blockings[i]);
  }
}

// koshi 20140121
void wbFilter(long long int UB, Solver& S,vec<Lit>& lits,
	      vec<long long int>& weights, vec<Lit>& blockings,
	      vec<long long int>& sweights, vec<Lit>& sblockings) {
  sweights.clear(); sblockings.clear();

  for(int i = 0; i < weights.size(); i++) {
    if (weights[i] < UB) {
      sweights.push(weights[i]);
      sblockings.push(blockings[i]);
    } else {
      lits.clear();
      lits.push(~blockings[i]);
      S.addClause(lits);
    }
  }
}

// koshi 2013.06.28
void genWarners0(vec<long long int>& weights, vec<Lit>& blockings,
		 long long int max,long long int k, int comp, Solver& S,
		  vec<Lit>& lits, vec<Lit>& linkingVar) {
  // koshi 20140109
  printf("c Warners' encoding for Cardinality Constraints\n");

  int logk = 1;
  while ((k >>= 1) > 0) logk++;
  Lit zero = mkLit(S.newVar());
  lits.clear();
  lits.push(~zero);
  S.addClause_(lits);
  genWarners(weights,blockings, max,logk, comp, S, zero,lits,linkingVar);
}

/*
  Cardinaltiy Constraints:
  Olivier Bailleux and Yacine Boufkhad,
  "Efficient CNF Encoding of Boolean Cardinality Constraints",
  CP 2003, LNCS 2833, pp.108-122, 2003
 */
// koshi 10.01.08
// 10.01.15 argument UB is added
void genBailleux(vec<long long int>& weights, vec<Lit>& blockings,
		 long long int total,
		 Lit zero, Lit one, int comp,Solver& S,
		 vec<Lit>& lits, vec<Lit>& linkingVar, long long int UB) {
  assert(weights.size() == blockings.size());

  linkingVar.clear();
  bool dvar = (comp == 11) ? false : true;

  vec<Lit> linkingAlpha;
  vec<Lit> linkingBeta;

  if (blockings.size() == 1) {// koshi 20140121
    long long int weight = weights[0];
    assert(weight < UB);
    linkingVar.push(one);
    for(int i = 0; i<weight; i++) linkingVar.push(blockings[0]);
    linkingVar.push(zero);
  } else if (blockings.size() > 1) {
    long long int weightL = 0; long long int weightR = 0;
    vec<long long int> weightsL, weightsR;
    vec<Lit> blockingsL, blockingsR;
    long long int half = total/2;
    wbsplit(half, weightL,weightR, weights,blockings,
	    weightsL,blockingsL, weightsR,blockingsR);

    genBailleux(weightsL,blockingsL,weightL,
		zero,one, comp,S, lits, linkingAlpha, UB);
    genBailleux(weightsR,blockingsR,weightR,
		zero,one, comp,S, lits, linkingBeta, UB);

    weightsL.clear();blockingsL.clear();
    weightsR.clear();blockingsR.clear();

    linkingVar.push(one);
    for (int i = 0; i < total && i <= UB; i++)
      linkingVar.push(mkLit(S.newVar(true,dvar)));
    linkingVar.push(zero);

    for (long long int sigma = 0; sigma <= total && sigma <= UB; sigma++) {
      for (long long int alpha = 0;
	   alpha < linkingAlpha.size()-1 && alpha <= UB;
	   alpha++) {
	long long int beta = sigma - alpha;
	if (0 <= beta && beta < linkingBeta.size()-1 && beta <= UB) {
	  lits.clear();
	  lits.push(~linkingAlpha[alpha]);
	  lits.push(~linkingBeta[beta]);
	  lits.push(linkingVar[sigma]);
	  S.addClause_(lits);
	  if (comp >= 10) {
	    lits.clear();
	    lits.push(linkingAlpha[alpha+1]);
	    lits.push(linkingBeta[beta+1]);
	    lits.push(~linkingVar[sigma+1]);
	    S.addClause_(lits);
	  }
	}
      }
    }
  }
  linkingAlpha.clear();
  linkingBeta.clear();
}

void genBailleux0(vec<long long int>& weights, vec<Lit>& blockings,
		  long long int max, long long int k, int comp, Solver& S,
		  vec<Lit>& lits, vec<Lit>& linkingVar) {
  // koshi 20140109
  printf("c Bailleux's encoding for Cardinailty Constraints k = %d\n", k);

  Lit one = mkLit(S.newVar());
  lits.clear();
  lits.push(one);
  S.addClause_(lits);

  genBailleux(weights,blockings,max, ~one,one, comp,S, lits, linkingVar, k);
}

/*
  Cardinaltiy Constraints:
  Robert Asin, Robert Nieuwenhuis, Albert Oliveras, Enric Rodriguez-Carbonell
  "Cardinality Networks: a theoretical and empirical study",
  Constraints (2011) 16:195-221
 */
// koshi 2013.07.01
inline void sComparator(Lit& a, Lit& b, Lit& c1, Lit& c2,
		       int comp,Solver& S, vec<Lit>& lits) {
  lits.clear();
  lits.push(~a); lits.push(~b); lits.push(c2);
  S.addClause_(lits);
  lits.clear();
  lits.push(~a); lits.push(c1);
  S.addClause_(lits);
  lits.clear();
  lits.push(~b); lits.push(c1);
  S.addClause_(lits);
  if (comp >= 10) {
    lits.clear();
    lits.push(a); lits.push(b); lits.push(~c1);
    S.addClause_(lits);
    lits.clear();
    lits.push(a); lits.push(~c2);
    S.addClause_(lits);
    lits.clear();
    lits.push(b); lits.push(~c2);
    S.addClause_(lits);
  }
}

// koshi 2013.07.01
void genSMerge(vec<Lit>& linkA, vec<Lit>& linkB,
	      Lit zero, Lit one, int comp,Solver& S,
	      vec<Lit>& lits, vec<Lit>& linkingVar, long long int UB) {

  /* koshi 2013.12.10
  assert(UB > 0); is violated when k <= 1
  */

  bool lessthan = (linkA.size() <= linkB.size());
  vec<Lit> &tan = lessthan ? linkA : linkB;
  vec<Lit> &tyou = lessthan ? linkB : linkA;
  assert(tan.size() <= tyou.size());

  linkingVar.clear();
  bool dvar = (comp == 11) ? false : true;

  if (tan.size() == 0)
    for(long long int i = 0; i < tyou.size(); i++) linkingVar.push(tyou[i]);
  else if (tan.size() == 1 && tyou.size() == 1) {
    Lit c1 = mkLit(S.newVar(true,dvar));
    Lit c2 = mkLit(S.newVar(true,dvar));
    linkingVar.push(c1); linkingVar.push(c2);
    sComparator(tan[0],tyou[0], c1,c2, comp,S, lits);
  } else {
    vec<Lit> oddA,oddB, evenA,evenB;
    oddA.clear(); oddB.clear(); evenA.clear(); evenB.clear();

    long long int i;
    for(i = 0; i < tan.size(); i++) {
      if (i%2 == 0) {
	evenA.push(tan[i]); evenB.push(tyou[i]);
      } else {
	oddA.push(tan[i]); oddB.push(tyou[i]);
      }
    }
    for(; i < tyou.size(); i++) {
      if (i%2 == 0) {
	evenA.push(zero); evenB.push(tyou[i]);
      } else {
	oddA.push(zero); oddB.push(tyou[i]);
      }
    }

    // koshi 2013.07.04
    long long int UBceil = UB/2 + UB%2;
    long long int UBfloor = UB/2;
    assert(UBfloor <= UBceil);
    vec<Lit> d, e;
    genSMerge(evenA,evenB, zero,one, comp,S, lits, d, UBceil);
    genSMerge(oddA,oddB, zero,one, comp,S, lits, e, UBfloor);
    oddA.clear(); oddB.clear(); evenA.clear(); evenB.clear();

    linkingVar.push(d[0]);

    assert(d.size() >= e.size());

    while (d.size() > e.size()) e.push(zero);
    for(i = 0; i < e.size()-1; i++) {
      Lit c2i = mkLit(S.newVar(true,dvar));
      Lit c2ip1 = mkLit(S.newVar(true,dvar));
      linkingVar.push(c2i); linkingVar.push(c2ip1);
      sComparator(d[i+1],e[i], c2i,c2ip1, comp,S, lits);
    }

    linkingVar.push(e[i]);

    for (long long int i = UB+1; i < linkingVar.size(); i++) {
      lits.clear();
      lits.push(~linkingVar[i]);
      S.addClause_(lits);
    }
    long long int ssize = linkingVar.size() - UB - 1;
    if (ssize > 0) linkingVar.shrink(ssize);

    d.clear(); e.clear();
  }

}
// koshi 2013.07.01
void genKCard(vec<long long int>& weights, vec<Lit>& blockings,
	      long long int total,
	      Lit zero, Lit one, int comp,Solver& S,
	      vec<Lit>& lits, vec<Lit>& linkingVar, long long int UB) {

  linkingVar.clear();

  if (blockings.size() == 1) {
    long long int weight = weights[0];
    assert(weight <= UB);
    // koshi 20140121
    for(int i = 0; i<weight; i++) linkingVar.push(blockings[0]);
  } else if (blockings.size() > 1) {
    vec<Lit> linkingAlpha;
    vec<Lit> linkingBeta;

    long long int weightL = 0; long long int weightR = 0;
    vec<long long int> weightsL, weightsR;
    vec<Lit> blockingsL, blockingsR;
    long long int half = total/2;
    wbsplit(half,weightL,weightR, weights,blockings,
	    weightsL,blockingsL, weightsR,blockingsR);

    genKCard(weightsL,blockingsL,weightL,
		zero,one, comp,S, lits, linkingAlpha, UB);
    genKCard(weightsR,blockingsR,weightR,
		zero,one, comp,S, lits, linkingBeta, UB);

    genSMerge(linkingAlpha,linkingBeta, zero,one, comp,S, lits, linkingVar, UB);

    linkingAlpha.clear();
    linkingBeta.clear();
  }
}

// koshi 2013.07.01
void genAsin(vec<long long int>& weights, vec<Lit>& blockings,
		  long long int max, long long int k, int comp, Solver& S,
		  vec<Lit>& lits, vec<Lit>& linkingVar) {
  // koshi 20140109
  printf("c Asin's encoding for Cardinailty Constraints\n");

  Lit one = mkLit(S.newVar());
  lits.clear();
  lits.push(one);
  S.addClause_(lits);

  genKCard(weights,blockings,max, ~one,one, comp,S, lits, linkingVar, k);
}


/*
  Cardinaltiy Constraints:
  Toru Ogawa, YangYang Liu, Ryuzo Hasegawa, Miyuki Koshimura, Hiroshi Fujita,
  "Modulo Based CNF Encoding of Cardinality Constraints and Its Application to
   MaxSAT Solvers",
  ICTAI 2013.
 */
// koshi 2013.10.03
void genOgawa(long long int weightX, vec<Lit>& linkingX,
	      long long int weightY, vec<Lit>& linkingY,
	      long long int& total, long long int divisor,
	      Lit zero, Lit one, int comp,Solver& S,
	      vec<Lit>& lits, vec<Lit>& linkingVar, long long int UB) {

  total = weightX+weightY;
  if (weightX == 0)
    for(int i = 0; i < linkingY.size(); i++) linkingVar.push(linkingY[i]);
  else if (weightY == 0)
    for(int i = 0; i < linkingX.size(); i++) linkingVar.push(linkingX[i]);
  else {
    long long int upper= total/divisor;
    long long int divisor1=divisor-1;
    /*
    printf("weightX = %lld, linkingX.size() = %d ", weightX,linkingX.size());
    printf("weightY = %lld, linkingY.size() = %d\n", weightY,linkingY.size());
    printf("upper = %lld, divisor1 = %lld\n", upper,divisor1);
    */

    linkingVar.push(one);
    for (int i = 0; i < divisor1; i++) linkingVar.push(mkLit(S.newVar()));
    linkingVar.push(one);
    for (int i = 0; i < upper; i++) linkingVar.push(mkLit(S.newVar()));
    Lit carry = mkLit(S.newVar());

    // lower part
    for (int i = 0; i < divisor; i++)
      for (int j = 0; j < divisor; j++) {
	int ij = i+j;
	lits.clear();
	lits.push(~linkingX[i]);
	lits.push(~linkingY[j]);
	if (ij < divisor) {
	  lits.push(linkingVar[ij]);
	  lits.push(carry);
	} else if (ij == divisor) lits.push(carry);
	else if (ij > divisor) lits.push(linkingVar[ij%divisor]);
	S.addClause_(lits);
      }

    // upper part
    for (int i = divisor; i < linkingX.size(); i++)
      for (int j = divisor; j < linkingY.size(); j++) {
	int ij = i+j-divisor;
	lits.clear();
	lits.push(~linkingX[i]);
	lits.push(~linkingY[j]);
	if (ij < linkingVar.size()) lits.push(linkingVar[ij]);
	S.addClause_(lits);
	//	printf("ij = %lld, linkingVar.size() = %lld\n",ij,linkingVar.size());
	lits.clear();
	lits.push(~carry);
	lits.push(~linkingX[i]);
	lits.push(~linkingY[j]);
	if (ij+1 < linkingVar.size()) lits.push(linkingVar[ij+1]);
	S.addClause_(lits);
      }
  }
  linkingX.clear(); linkingY.clear();
}

void genOgawa(vec<long long int>& weights, vec<Lit>& blockings,
	      long long int& total, long long int divisor,
	      Lit zero, Lit one, int comp,Solver& S,
	      vec<Lit>& lits, vec<Lit>& linkingVar, long long int UB) {

  linkingVar.clear();

  vec<Lit> linkingAlpha;
  vec<Lit> linkingBeta;

  if (total < divisor) {
    vec<Lit> linking;
    genBailleux(weights,blockings,total,
		zero,one, comp,S, lits, linking, UB);
    total = linking.size()-2;
    for(int i = 0; i < divisor; i++)
      if (i < linking.size()) linkingVar.push(linking[i]);
      else linkingVar.push(zero);
    linkingVar.push(one);
    linking.clear();
    //    printf("total = %lld, linkngVar.size() = %d\n", total,linkingVar.size());
  } else if (blockings.size() == 1) {
    long long int weight = weights[0];
    if (weight < UB) {
      long long int upper = weight/divisor;
      long long int lower = weight%divisor;
      long long int pad = divisor-lower-1;
      linkingVar.push(one);
      for (int i = 0; i < lower; i++) linkingVar.push(blockings[0]);
      for (int i = 0; i < pad; i++) linkingVar.push(zero);
      linkingVar.push(one);
      for (int i = 0; i < upper; i++) linkingVar.push(blockings[0]);
      total = weight;
    } else {
      lits.clear();
      lits.push(~blockings[0]);
      S.addClause_(lits);
      total = 0;
    }
  } else if (blockings.size() > 1) {
    long long int weightL = 0; long long int weightR = 0;
    vec<long long int> weightsL, weightsR;
    vec<Lit> blockingsL, blockingsR;
    long long int half = total/2;
    wbsplit(half, weightL,weightR, weights,blockings,
	    weightsL,blockingsL, weightsR,blockingsR);

    genOgawa(weightsL,blockingsL,weightL,divisor,
	     zero,one, comp,S, lits, linkingAlpha, UB);
    genOgawa(weightsR,blockingsR,weightR,divisor,
	     zero,one, comp,S, lits, linkingBeta, UB);

    weightsL.clear();blockingsL.clear();
    weightsR.clear();blockingsR.clear();

    genOgawa(weightL,linkingAlpha, weightR,linkingBeta, total,divisor,
	      zero,one, comp,S, lits, linkingVar, UB);
  }
  // koshi 2013.11.12
  long long int upper = (UB-1)/divisor;
  for (long long int i = divisor+upper+1; i < linkingVar.size(); i++) {
    lits.clear();
    lits.push(~linkingVar[i]);
    S.addClause_(lits);
  }
  while (divisor+upper+2 < linkingVar.size()) linkingVar.shrink(1);
}

void genOgawa0(int& card, // koshi 2013.12.24
	       vec<long long int>& weights, vec<Lit>& blockings,
	       long long int max, long long int k,
	       long long int& divisor, int comp, Solver& S,
	       vec<Lit>& lits, vec<Lit>& linkingVar) {
  //  koshi 20140327 assert(max >= TOTALIZER);

  /* koshi 2013.11.11
  long long int max0 = max;
  */
  long long int k0 = k;
  long long int odd = 1;
  divisor = 0;
  /* koshi 2013.11.11
  while (max0 > 0) {
    divisor++;
    max0 -= odd;
    odd += 2;
  }
  */
  while (k0 > 0) {
    divisor++;
    k0 -= odd;
    odd += 2;
  }
  printf("c max = %lld, divisor = %lld\n", max,divisor);

  // koshi 2013.12.24
  if (divisor <= 2) {
    printf("c divisor is less than or equal to 2 ");
    printf("so we use Warner's encoding, i.e. -card=warn\n");
    card = 0;
    genWarners0(weights,blockings, max,k, comp, S, lits,linkingVar);
  } else {
    // koshi 20140109
    printf("c Ogawa's encoding for Cardinality Constraints\n");

    Lit one = mkLit(S.newVar());
    lits.clear();
    lits.push(one);
    S.addClause_(lits);
    genOgawa(weights,blockings, max,divisor,
	     ~one,one, comp,S, lits, linkingVar, k);
  }
}


//TODO BailW2 K-WTO
void genBailleuxW2(vec<long long int>& weights, vec<Lit>& blockings,long long int total,Lit zero, Lit one,
		int comp,Solver& S,vec<Lit>& lits, vec<Lit>& linkingVar,vec<long long int>& linkingW , long long int UB) {

	assert(weights.size() == blockings.size());

	linkingVar.clear();
	linkingW.clear();
	bool dvar = (comp == 11) ? false : true;

	vec<Lit> linkingAlpha;
	vec<Lit> linkingBeta;

	vec<long long int> linkingWA;
	vec<long long int> linkingWB;

	if (blockings.size() == 1) {// koshi 20140121

		//1個のとき

		long long int weight = weights[0];

		if(weight >= UB){
			printf("weight(%lld) is over %lld\n" , weight , UB);
			exit(1);
		}
		//assert(weight < UB);

		linkingVar.push(one);
		linkingW.push(0);

		linkingVar.push(blockings[0]);
		linkingW.push(weights[0]);

	} else if (blockings.size() > 1) {

		//2個以上のとき

		long long int weightL = 0; long long int weightR = 0;
		vec<long long int> weightsL, weightsR;
		vec<Lit> blockingsL, blockingsR;
		long long int half = total/2;

		//weightsとblockingsを半分に分ける
		wbsplit(half , weightL , weightR , weights , blockings , weightsL , blockingsL , weightsR , blockingsR);

		//LEFT
		genBailleuxW2(weightsL,blockingsL,weightL,zero,one, comp,S, lits, linkingAlpha,linkingWA , UB);

		//RIGHT
		genBailleuxW2(weightsR,blockingsR,weightR,zero,one, comp,S, lits, linkingBeta,linkingWB, UB);

		weightsL.clear();
		blockingsL.clear();
		weightsR.clear();
		blockingsR.clear();

		long long int top = ((UB < total) ? UB : total+1);
		int *table = new int[top];

		table[0] = 1;
		for (int i = 1 ; i < top ; i++){

			table[i] = 0;

		}

		int a_size = linkingWA.size();
		int b_size = linkingWB.size();

		linkingW.clear();
		linkingVar.clear();

		linkingVar.push(one);
		linkingW.push(0);

		for(int b = 1 ; b < b_size ; ++b){

			//2015 02 07
			if(linkingWB[b] < top){

				linkingVar.push(mkLit(S.newVar(true,dvar)));	//変数生成
				linkingW.push(linkingWB[b]);

				//新しく節を生成して追加
				lits.clear();
				lits.push(~linkingBeta[b]);
				lits.push(linkingVar[linkingVar.size()-1]);
				S.addClause_(lits);

				//printf("[ %d ]" , var(linkingVar[linkingVar.size()-1]));

				table[linkingWB[b]] = linkingVar.size();//1になっていたのをlinkingVar.size()に修正　2015 01 24

			}else{

				lits.clear();
				lits.push(~linkingBeta[b]);
				S.addClause_(lits);

			}

		}


		for(int a = 1 ; a < a_size ; ++a){

			long long int wa = linkingWA[a];

			if(wa >= top){
				lits.clear();
				lits.push(~linkingAlpha[a]);
				S.addClause_(lits);
				continue;

			}

			for(long long int b = 0 ; b < b_size ; ++b){

				long long int wb = linkingWB[b];

				if(wa + wb < top){

					if(table[wa + wb] == 0){//新しい重みの和
						linkingVar.push(mkLit(S.newVar(true,dvar)));	////変数生成
						linkingW.push(wa + wb);
						table[wa+wb] = linkingVar.size();	//重み(wa+wb)がlinkingVarの何番目に対応するかを記録
						//printf("[ %d ]" , var(linkingVar[linkingVar.size()-1]));
					}

					//新しく節を生成して追加
					lits.clear();
					lits.push(~linkingAlpha[a]);
					lits.push(~linkingBeta[b]);
					lits.push(linkingVar[table[wa+wb]-1]);
					S.addClause_(lits);

				}else{
					lits.clear();
					lits.push(~linkingAlpha[a]);
					lits.push(~linkingBeta[b]);
					S.addClause_(lits);
				}

			}

		}

		delete []table;

	}


	linkingAlpha.clear();
	linkingBeta.clear();
	linkingWA.clear();
	linkingWB.clear();

}

void genBailleuxW20(vec<long long int>& weights, vec<Lit>& blockings,
		  long long int max, long long int k, int comp, Solver& S,
		  vec<Lit>& lits, vec<Lit>& linkingVar , vec<long long int>& linkingWeight) {
  // hayata 2014/12/17
	//printf("\nTOを構築 =====================================================\n")

	//printf("\n[bailW]\n");

	printf("c WTO encoding for Cardinailty Constraints\n");


	Lit one = mkLit(S.newVar());
	lits.clear();
	lits.push(one);
	S.addClause_(lits);

	//printf("one = %d\n" , var(one)+1);

	genBailleuxW2(weights,blockings,max, ~one,one, comp,S, lits, linkingVar,linkingWeight, k);

}




void genCCl(Lit a, Solver& S,vec<Lit>& lits,Var varZero) { //ogawa 2013/04/02 uemura 20161129
  lits.clear();  // lits and varZero defined as global vars
  if (var(a)==varZero) {if (sign(a)==0) return;} else lits.push(a);
  S.addClause_(lits);
}

void genCCl(Lit a, Lit b, Solver& S,vec<Lit>& lits,Var varZero) {//ogawa 2013/04/02 uemura 20161129
  lits.clear();  // lits and varZero defined as global vars
  if (var(a)==varZero) {if (sign(a)==0) return;} else lits.push(a);
  if (var(b)==varZero) {if (sign(b)==0) return;} else lits.push(b);
  S.addClause_(lits);
}

void genCCl(Lit a, Lit b, Lit c, Solver& S,vec<Lit>& lits,Var varZero) {//ogawa 2013/04/02 uemura 20161129
  lits.clear();  // lits and varZero defined as global vars
  if (var(a)==varZero) {if (sign(a)==0) return;} else lits.push(a);
  if (var(b)==varZero) {if (sign(b)==0) return;} else lits.push(b);
  if (var(c)==varZero) {if (sign(c)==0) return;} else lits.push(c);
  S.addClause_(lits);
}

void genCCl1(Lit a, Lit b, Lit c, Solver& S,vec<Lit>& lits,Var varZero) {//ogawa 2013/04/02 uemura 20161129
  lits.clear();  // lits and varZero defined as global vars
  printf("fe");
  if (var(a)==varZero) {if (sign(a)==0) return;} else lits.push(a);
  if (var(b)==varZero) {if (sign(b)==0) return;} else lits.push(b);
  if (var(c)==varZero) {if (sign(c)==0) return;} else lits.push(c);
  S.addClause_(lits);
}

void genCCl(Lit a, Lit b, Lit c, Lit d, Solver& S,vec<Lit>& lits,Var varZero) {//ogawa 2013/04/02 uemura 20161129
  lits.clear();  // lits and varZero defined as global vars
  if (var(a)==varZero) {if (sign(a)==0) return;} else lits.push(a);
  if (var(b)==varZero) {if (sign(b)==0) return;} else lits.push(b);
  if (var(c)==varZero) {if (sign(c)==0) return;} else lits.push(c);
  if (var(d)==varZero) {if (sign(d)==0) return;} else lits.push(d);

  S.addClause(lits);
}

void genCCl(Lit a, Lit b, Lit c, Lit d, Lit e, Solver& S,vec<Lit>& lits,Var varZero) {//ogawa 2013/04/02 uemura 20161129
  lits.clear();  // lits and varZero defined as global vars
  if (var(a)==varZero) {if (sign(a)==0) return;} else lits.push(a);
  if (var(b)==varZero) {if (sign(b)==0) return;} else lits.push(b);
  if (var(c)==varZero) {if (sign(c)==0) return;} else lits.push(c);
  if (var(d)==varZero) {if (sign(d)==0) return;} else lits.push(d);
  if (var(e)==varZero) {if (sign(e)==0) return;} else lits.push(e);
  S.addClause(lits);
}

//uemura 20161129
void genKWMTO( vec<long long int>& weights ,vec<Lit>& blockings ,vec<long long int>& weightsTable,
		int from, int to, int div,Lit zero,
		vec<Lit>& lower,vec<long long int>& lowerW,vec<Lit>& upper,vec<long long int>& upperW,
		Solver& S, long long int ub,vec<Lit>& lits,Var varZero) {

	int inputsize = to-from+1;
	lower.clear();
	lowerW.clear();
	upper.clear();
	upperW.clear();

	if(inputsize == 1){
		//1個のとき

		long long int weight = weights[from];

		int low = weight % div;
		int up = weight / div;

		lower.push(zero);
		lowerW.push(0);

		if(low > 0){
			lower.push(blockings[from]);
			lowerW.push(low);
		}

		upper.push(zero);
		upperW.push(0);

		if(up > 0){
			upper.push(blockings[from]);
			upperW.push(up);
		}



	}else{

		int middle = inputsize/2;
		vec<Lit> alphaLow;
		vec<Lit> betaLow;
		vec<long long int> WalphaLow;
		vec<long long int> WbetaLow;

		vec<Lit> alphaUp;
		vec<Lit> betaUp;
		vec<long long int> WalphaUp;
		vec<long long int> WbetaUp;

		genKWMTO(weights ,blockings,weightsTable,from, from+middle-1,div,zero, alphaLow,WalphaLow,alphaUp,WalphaUp, S, ub,lits,varZero);

		genKWMTO(weights ,blockings,weightsTable,from+middle, to, div,zero,betaLow,WbetaLow,betaUp,WbetaUp, S, ub,lits,varZero);


		long long int total = weightsTable[to] - weightsTable[from] + weights[from];

		//LOWERの処理=====================================================================================


		int *tableLOW = new int[div];

		tableLOW[0] = 1;
		for (int i = 1 ; i < div ; i++){

			tableLOW[i] = 0;

		}

		int a_size = WalphaLow.size();
		int b_size = WbetaLow.size();

		lowerW.clear();
		lower.clear();

		lower.push(zero);
		lowerW.push(0);


		Lit C = mkLit(S.newVar());

		for(int a = 0 ; a < a_size ; ++a){

			long long int wa = WalphaLow[a];
			//printf("wa = %d\n",wa);

			for(long long int b = 0 ; b < b_size ; ++b){

				long long int wb = WbetaLow[b];
				//printf("wb = %d\n",wb);

				long long int wab = (wa + wb)%div;


				if(wa + wb < div){

					if(tableLOW[wab] == 0){//新しい重みの和
						lower.push(mkLit(S.newVar()));
						lowerW.push(wab);
						tableLOW[wab] = lower.size();	//重み(wa+wb)がlinkingVarの何番目に対応するかを記録
						//printf("lower.size = %d\n",lower.size());

					}

					genCCl(~alphaLow[a] , ~betaLow[b] , lower[tableLOW[wab]-1] , C , S,lits,varZero);
					//printf("ClauseLOW[-%d(a=%d) -%d(b=%d) %d c]\n" ,alphaLow[a],a,~betaLow[b], b,lower[tableLOW[wab]-1]);//arimura

					  /*for(int i = 0 ; i < Lits.size() ; ++i){
						  printf("%s%d %s " , sign(Lits[i]) == 1 ? "-" : "" , var(Lits[i]) , i == Lits.size()-1 ? "\n" : "v");
					  }*/
				}else if(wab == 0){
					if(a!=0||b!=0){
					genCCl(~alphaLow[a] , ~betaLow[b] , C , S,lits,varZero);
					//printf("LOwerwab==0\n");
					}
					  /*for(int i = 0 ; i < Lits.size() ; ++i){
						  printf("%s%d %s " , sign(Lits[i]) == 1 ? "-" : "" , var(Lits[i]) , i == Lits.size()-1 ? "\n" : "v");
					  }*/
				}else{// wa + wb > div

					if(tableLOW[wab] == 0){//新しい重みの和

						lower.push(mkLit(S.newVar()));
						lowerW.push(wab);
						tableLOW[wab] = lower.size();	//重み(wa+wb)%divがlinkingVarの何番目に対応するかを記録
						//printf("lower.size = %d\n",lower.size());

					}

					genCCl(~alphaLow[a] , ~betaLow[b] , lower[tableLOW[wab]-1] , S,lits,varZero);
					genCCl(~alphaLow[a] , ~betaLow[b] , C , S,lits,varZero);
					//printf("ClauseLOW[-%d(a=%d) -%d(b=%d) %d c]\n" ,alphaLow[a],a,~betaLow[b], b,lower[tableLOW[wab]-1]);//arimura
					//printf("ClauseLOW[-%d(a=%d) -%d(b=%d) c]\n" ,alphaLow[a],a,~betaLow[b], b);//arimura
					  /*for(int i = 0 ; i < Lits.size() ; ++i){
						  printf("%s%d %s " , sign(Lits[i]) == 1 ? "-" : "" , var(Lits[i]) , i == Lits.size()-1 ? "\n" : "v");
					  }*/
				}

			}

		}

		delete []tableLOW;


		WalphaLow.clear();
		WbetaLow.clear();
		alphaLow.clear();
		betaLow.clear();

		//UPPERの処理=====================================================================================

		//long long int UBU = _min(ub , total)/div;//upperの上限値
		//long long int UBU = _min(total , total)/div + 1;//upperの上限値
		long long int UBU = total/div + 1;//upperの上限値 uemura 20161129

		int *tableUP = new int[UBU+1];

		tableUP[0] = 1;
		for (int i = 1 ; i <= UBU ; i++){

			tableUP[i] = 0;

		}

		a_size = WalphaUp.size();
		b_size = WbetaUp.size();

		upperW.clear();
		upper.clear();

		upper.push(zero);
		upperW.push(0);

		for(int a = 0 ; a < a_size ; ++a){

			long long int wa = WalphaUp[a];

			for(long long int b = 0 ; b < b_size ; ++b){

				long long int wb = WbetaUp[b];

				long long int wab = wa + wb;//キャリーなしの場合

				if(UBU < wab){//超えてる場合

					//新しく節を生成して追加
					genCCl(~alphaUp[a] , ~betaUp[b] , S,lits,varZero);
					 /* for(int i = 0 ; i < Lits.size() ; ++i){
						  printf("%s%d %s " , sign(Lits[i]) == 1 ? "-" : "" , var(Lits[i]) , i == Lits.size()-1 ? "\n" : "v");
					  }*/
				}else{

					if(wab > 0){

						if(tableUP[wab] == 0){//新しい重みの和
							upper.push(mkLit(S.newVar()));
							upperW.push(wab);
							tableUP[wab] = upper.size();	//重み(wa+wb)がlinkingVarの何番目に対応するかを記録
							//printf("[ %d ]" , var(linkingVar[linkingVar.size()-1]));
						}

						//新しく節を生成して追加
						genCCl(~alphaUp[a] , ~betaUp[b] , upper[tableUP[wab]-1] , S,lits,varZero);
						  /*for(int i = 0 ; i < Lits.size() ; ++i){
							  printf("%s%d %s " , sign(Lits[i]) == 1 ? "-" : "" , var(Lits[i]) , i == Lits.size()-1 ? "\n" : "v");
						  }*/
					}

				}

				wab = wa + wb + 1;//キャリーつきの場合

				if(UBU < wab){//超えてる場合

						genCCl(~alphaUp[a] , ~betaUp[b] , ~C , S,lits,varZero);
						  /*for(int i = 0 ; i < Lits.size() ; ++i){
							  printf("%s%d %s " , sign(Lits[i]) == 1 ? "-" : "" , var(Lits[i]) , i == Lits.size()-1 ? "\n" : "v");
						  }*/
				}else{

					if(tableUP[wab] == 0){//新しい重みの和
						upper.push(mkLit(S.newVar()));
						upperW.push(wab);
						tableUP[wab] = upper.size();	//重み(wa+wb)がlinkingVarの何番目に対応するかを記録
					}


					genCCl(~alphaUp[a] , ~betaUp[b] , ~C ,upper[tableUP[wab]-1] , S,lits,varZero);
					if(wab == UBU){//test 2015 03 19
						genCCl(~upper[tableUP[wab]-1] , ~C , S,lits,varZero);
						//printf("OVER CARRY\n");
					}
					  /*for(int i = 0 ; i < Lits.size() ; ++i){
						  printf("%s%d %s " , sign(Lits[i]) == 1 ? "-" : "" , var(Lits[i]) , i == Lits.size()-1 ? "\n" : "v");
					  }*/
				}

			}

		}

		/*fprintf(stderr , "LOW(%d) ",lowerW.size());
		for(int i = 1 ; i < lowerW.size(); ++i){
			fprintf(stderr , "%lld " , lowerW[i]);

		}
		fprintf(stderr , "\nUP(%d) " , upperW.size());
		for(int i = 1 ; i < upperW.size(); ++i){
			fprintf(stderr , "%lld " , upperW[i]);
		}
		fprintf(stderr , "\n");*/
		//if(carry){

		//}
		//printf("linkingVarUP.size = %d\n" , linkingVarUP.size());

		delete []tableUP;

		WalphaUp.clear();
		WbetaUp.clear();
		alphaUp.clear();
		betaUp.clear();

		//printf("C = %d " , var(C));

	}

	/*printf("\nU = { ");
	for(int i = 0 ; i < upper.size() ; ++i)
		printf("%lld " , upperW[i]);

	printf("} L = { ");
	for(int i = 0 ; i < lower.size() ; ++i)
		printf("%lld " , lowerW[i]);

	printf("}");*/

	/*printf("U = { ");
	for(int i = 0 ; i < upper.size() ; ++i)
		printf("%d(%lld) " , var(upper[i]) , upperW[i]);

	printf("} L = { ");
	for(int i = 0 ; i < lower.size() ; ++i)
		printf("%d(%lld) " , var(lower[i]) , lowerW[i]);

	printf("}\n");*/


}


void genKWMTO0(int& card, vec<long long int>& weights, vec<Lit>& blockings ,
		long long int max, long long int k,
		vec<long long int>& divisors,
		Solver& S,vec<Lit>& lits,
		vec<vec<Lit> >& linkingVars, vec<vec<long long int> >& linkingWeights){
	printf("c WMTO encoding for Cardinailty Constraints\n");

	for(int i = 0;i<2;i++){
		linkingVars.push();
		linkingWeights.push();
	}


	divisors.push(pow(max,1.0/2.0));
	printf("c p = %lld\n",divisors[0]);

	vec<long long int> weightsTable;
	long long int tmp = 0;
	int size = blockings.size();

	for(int i = 0 ; i < size ; ++i){
		tmp += weights[i];
		weightsTable.push(tmp);
	}

	Lit zero = mkLit(S.newVar());
	lits.clear();
	lits.push(zero);
	S.addClause_(lits);

	Var varZero = var(zero);

	genKWMTO( weights ,blockings , weightsTable , 0, size-1 ,divisors[0],zero, linkingVars[0] , linkingWeights[0] ,linkingVars[1] , linkingWeights[1] , S , k,lits,varZero);

}




//MRWTO UEMURA 20161112
void genMRWTO(vec<long long int>& weights ,vec<Lit>& blockings ,vec<long long int>& weightsTable,
		int from, int to, vec<long long int>& divisors,Lit zero,
		vec<vec<Lit> >& linkingVars,vec<vec<long long int> >& linkingWeights,
		Solver& S, long long int ub,vec<Lit>& lits,Var varZero) {

	int ndigit = linkingVars.size();

	int inputsize = to-from+1;

	for(int i = 0;i<ndigit;i++){
		linkingVars[i].clear();
		linkingWeights[i].clear();
	}
	if(inputsize == 1){
		//1個のとき

		long long int tmpw = weights[from];
		int *digit = new int[ndigit];

		for(int i = 0;i<ndigit-1;i++){
			digit[i] = tmpw % divisors[i];
			tmpw = tmpw / divisors[i];
		}
		digit[ndigit-1] = tmpw;

		for(int i=0;i<ndigit;i++){
			linkingVars[i].push(zero);
			linkingWeights[i].push(0);
			if(digit[i] > 0){
				linkingVars[i].push(blockings[from]);
				linkingWeights[i].push(digit[i]);
			}
		}

		delete []digit;
	}else{

		int middle = inputsize/2;

		vec<vec<Lit> > alphalinkingVars;
		vec<vec<Lit> > betalinkingVars;
		vec<vec<long long int> > alphalinkingWeights;
		vec<vec<long long int> > betalinkingWeights;
		for(int i = 0;i<ndigit;i++){
			alphalinkingVars.push();
			betalinkingVars.push();
			alphalinkingWeights.push();
			betalinkingWeights.push();
		}

		genMRWTO(weights ,blockings,weightsTable,from, from+middle-1,divisors,zero, alphalinkingVars,alphalinkingWeights, S, ub,lits,varZero);
		genMRWTO(weights ,blockings,weightsTable,from+middle, to, divisors,zero,betalinkingVars,betalinkingWeights, S, ub,lits,varZero);

		long long int total = weightsTable[to] - weightsTable[from] + weights[from];
		//Lit *C = new Lit[ndigit];
		vec<Lit> C;

		long long int prodiv;
		for(int cdigit = 0;cdigit<ndigit;cdigit++){
			//CyouRyuu
			if(cdigit != 0){
				prodiv = 1;
				for(int CR1=0; CR1<cdigit; ++CR1){
					prodiv = prodiv * divisors[CR1];
				}
			}
			//最下位桁の処理=====================================================================================
			if(cdigit == 0){
				C.push();
				int div = divisors[cdigit];
				int *tableLOW = new int[div];
				tableLOW[0] = 1;
				for (int i = 1 ; i < div ; i++){
					tableLOW[i] = 0;
				}
				int a_size = alphalinkingWeights[cdigit].size();
				int b_size = betalinkingWeights[cdigit].size();
				linkingVars[cdigit].clear();
				linkingWeights[cdigit].clear();
				linkingVars[cdigit].push(zero);
				linkingWeights[cdigit].push(0);
				C[cdigit] = mkLit(S.newVar());

				for(int a = 0 ; a < a_size ; ++a){
					long long int wa = alphalinkingWeights[cdigit][a];

					for(long long int b = 0 ; b < b_size ; ++b){

						long long int wb = betalinkingWeights[cdigit][b];
						long long int wab = (wa + wb)%div;
						if(wa + wb < div && wa+wb<=ub){
							if(tableLOW[wab] == 0){//新しい重みの和
								linkingVars[cdigit].push(mkLit(S.newVar()));
								linkingWeights[cdigit].push(wab);
								tableLOW[wab] = linkingVars[cdigit].size();	//重み(wa+wb)がlinkingVars[cdigit]の何番目に対応するかを記録
							}
							genCCl(~alphalinkingVars[cdigit][a] , ~betalinkingVars[cdigit][b] , linkingVars[cdigit][tableLOW[wab]-1] , C[cdigit] , S,lits,varZero);

						}else if(wab == 0 && wa+wb<=ub){
							if(a!=0||b!=0){
								genCCl(~alphalinkingVars[cdigit][a] , ~betalinkingVars[cdigit][b] , C[cdigit] , S,lits,varZero);
							}

						}else if(wa+wb<=ub){// wa + wb > div
							if(tableLOW[wab] == 0){//新しい重みの和
								linkingVars[cdigit].push(mkLit(S.newVar()));
								linkingWeights[cdigit].push(wab);
								tableLOW[wab] = linkingVars[cdigit].size();	//重み(wa+wb)%divがlinkingVarの何番目に対応するかを記録
							}
							genCCl(~alphalinkingVars[cdigit][a] , ~betalinkingVars[cdigit][b] , linkingVars[cdigit][tableLOW[wab]-1] , S,lits,varZero);
							genCCl(~alphalinkingVars[cdigit][a] , ~betalinkingVars[cdigit][b] , C[cdigit] , S,lits,varZero);
						}else{
							genCCl(~alphalinkingVars[cdigit][a] , ~betalinkingVars[cdigit][b], S,lits,varZero);
						}
					}
				}
				delete []tableLOW;
				//alphalinkingWeights[cdigit].clear();
				//betalinkingWeights[cdigit].clear();
				//alphalinkingVars[cdigit].clear();
				//betalinkingVars[cdigit].clear();
			}

			//中間桁の処理====================================================================================================
			else if(cdigit > 0 && cdigit < ndigit-1){
				C.push();
				int div = divisors[cdigit];
				int *tableMIDDLE = new int[div];
				tableMIDDLE[0] = 1;
				for (int i = 1 ; i < div ; i++){
					tableMIDDLE[i] = 0;
				}

				int a_size = alphalinkingWeights[cdigit].size();
				int b_size = betalinkingWeights[cdigit].size();
				linkingVars[cdigit].clear();
				linkingWeights[cdigit].clear();
				linkingVars[cdigit].push(zero);
				linkingWeights[cdigit].push(0);
				C[cdigit] = mkLit(S.newVar());
				for(int a = 0 ; a < a_size ; ++a){

					long long int wa = alphalinkingWeights[cdigit][a];

					for(long long int b = 0 ; b < b_size ; ++b){

						long long int wb = betalinkingWeights[cdigit][b];
						long long int wab = (wa + wb)%div;

						if(wa + wb < div && (wa+wb)*prodiv<=ub){

							if(tableMIDDLE[wab] == 0){//新しい重みの和
								linkingVars[cdigit].push(mkLit(S.newVar()));
								linkingWeights[cdigit].push(wab);
								tableMIDDLE[wab] = linkingVars[cdigit].size();	//重み(wa+wb)がlinkingVarの何番目に対応するかを記録
							}
							genCCl(~alphalinkingVars[cdigit][a] , ~betalinkingVars[cdigit][b] , linkingVars[cdigit][tableMIDDLE[wab]-1] , C[cdigit] , S,lits,varZero);

						}else if(wab == 0 && (wa+wb)*prodiv<=ub){
							if(a!=0||b!=0){
								genCCl(~alphalinkingVars[cdigit][a] , ~betalinkingVars[cdigit][b] , C[cdigit] , S,lits,varZero);
							}
						}else if((wa+wb)*prodiv<=ub){// wa + wb >= div

							if(tableMIDDLE[wab] == 0){//新しい重みの和
								linkingVars[cdigit].push(mkLit(S.newVar()));
								linkingWeights[cdigit].push(wab);
								tableMIDDLE[wab] = linkingVars[cdigit].size();	//重み(wa+wb)%divがlinkingVarの何番目に対応するかを記録
							}
							genCCl(~alphalinkingVars[cdigit][a] , ~betalinkingVars[cdigit][b] , linkingVars[cdigit][tableMIDDLE[wab]-1] , S,lits,varZero);
							genCCl(~alphalinkingVars[cdigit][a] , ~betalinkingVars[cdigit][b] , C[cdigit] , S,lits,varZero);
						}else{
							genCCl(~alphalinkingVars[cdigit][a] , ~betalinkingVars[cdigit][b], S,lits,varZero);
						}

						wab = (wa + wb + 1)%div; //carryがある場合
						if(wa + wb + 1 < div && (wa+wb+1)*prodiv<=ub){
							if(tableMIDDLE[wab] == 0){//新しい重みの和
								linkingVars[cdigit].push(mkLit(S.newVar()));
								linkingWeights[cdigit].push(wab);
								tableMIDDLE[wab] = linkingVars[cdigit].size();	//重み(wa+wb)がlinkingVarの何番目に対応するかを記録
							}
							genCCl(~C[cdigit-1],~alphalinkingVars[cdigit][a] , ~betalinkingVars[cdigit][b] , linkingVars[cdigit][tableMIDDLE[wab]-1] , C[cdigit] , S,lits,varZero);

						}else if(wab == 0 && (wa+wb+1)*prodiv<=ub){
							if(a!=0||b!=0){
								genCCl(~C[cdigit-1],~alphalinkingVars[cdigit][a] , ~betalinkingVars[cdigit][b] , C[cdigit] , S,lits,varZero);
							}

						}else if((wa+wb+1)*prodiv<=ub){// wa + wb + 1 > div

							if(tableMIDDLE[wab] == 0){//新しい重みの和
								linkingVars[cdigit].push(mkLit(S.newVar()));
								linkingWeights[cdigit].push(wab);
								tableMIDDLE[wab] = linkingVars[cdigit].size();	//重み(wa+wb)%divがlinkingVarの何番目に対応するかを記録
							}
							genCCl(~C[cdigit-1],~alphalinkingVars[cdigit][a] , ~betalinkingVars[cdigit][b] , linkingVars[cdigit][tableMIDDLE[wab]-1] , S,lits,varZero);
							genCCl(~C[cdigit-1],~alphalinkingVars[cdigit][a] , ~betalinkingVars[cdigit][b] , C[cdigit] , S,lits,varZero);
						}else{
							genCCl(~C[cdigit-1],~alphalinkingVars[cdigit][a] , ~betalinkingVars[cdigit][b], S,lits,varZero);
						}
					}
				}
				delete []tableMIDDLE;
				//alphalinkingWeights[cdigit].clear();
				//betalinkingWeights[cdigit].clear();
				//alphalinkingVars[cdigit].clear();
				//betalinkingVars[cdigit].clear();
			}


			//最上位桁の処理=====================================================================================
			else if(cdigit == ndigit-1){
				//long long int UBU = (total<ub?total:ub);	//linkingVars[cdigit]の上限値
				long long int UBU = total;
				for(int i = 0;i<cdigit;i++){
					UBU /= divisors[i];
				}
				UBU++;

				int *tableUP = new int[UBU+1];
				tableUP[0] = 1;
				for (int i = 1 ; i <= UBU ; i++){
					tableUP[i] = 0;
				}

				int a_size = alphalinkingWeights[cdigit].size();
				int b_size = betalinkingWeights[cdigit].size();
				linkingWeights[cdigit].clear();
				linkingVars[cdigit].clear();
				linkingVars[cdigit].push(zero);
				linkingWeights[cdigit].push(0);

				for(int a = 0 ; a < a_size ; ++a){

					long long int wa = alphalinkingWeights[cdigit][a];

					for(long long int b = 0 ; b < b_size ; ++b){

						long long int wb = betalinkingWeights[cdigit][b];

						long long int wab = wa + wb;//キャリーなしの場合

						if(UBU < wab || (wa+wb)*prodiv>ub){//超えてる場合
					//新しく節を生成して追加
							genCCl(~alphalinkingVars[cdigit][a] , ~betalinkingVars[cdigit][b] , S,lits,varZero);
						}else{
							if(wab > 0){
								if(tableUP[wab] == 0){//新しい重みの和
									linkingVars[cdigit].push(mkLit(S.newVar()));
									linkingWeights[cdigit].push(wab);
									tableUP[wab] = linkingVars[cdigit].size();	//重み(wa+wb)がlinkingVarの何番目に対応するかを記録
								}

								//新しく節を生成して追加
								genCCl(~alphalinkingVars[cdigit][a] , ~betalinkingVars[cdigit][b] , linkingVars[cdigit][tableUP[wab]-1] , S,lits,varZero);
							}
						}

						wab = wa + wb + 1;//キャリーつきの場合
						if(UBU < wab || (wa+wb+1)*prodiv>ub){//超えてる場合
							genCCl(~alphalinkingVars[cdigit][a] , ~betalinkingVars[cdigit][b] , ~C[cdigit-1] , S,lits,varZero);
						}else{
							if(tableUP[wab] == 0){//新しい重みの和
								linkingVars[cdigit].push(mkLit(S.newVar()));
								linkingWeights[cdigit].push(wab);
								tableUP[wab] = linkingVars[cdigit].size();	//重み(wa+wb)がlinkingVarの何番目に対応するかを記録
							}
							genCCl(~alphalinkingVars[cdigit][a] , ~betalinkingVars[cdigit][b] , ~C[cdigit-1] ,linkingVars[cdigit][tableUP[wab]-1] , S,lits,varZero);
							if(wab == UBU){//test 2015 03 19
								genCCl(~linkingVars[cdigit][tableUP[wab]-1] , ~C[cdigit-1] , S,lits,varZero);
							}
						}
					}
				}
				delete []tableUP;
			}
		}
		C.clear();
		alphalinkingWeights.clear();
		betalinkingWeights.clear();
		alphalinkingVars.clear();
		betalinkingVars.clear();
	}
}

void genMRWTO0(int& card, vec<long long int>& weights, vec<Lit>& blockings ,
		long long int max, long long int k,
		vec<long long int>& divisors,
		Solver& S,vec<Lit>& lits,
		vec<vec<Lit> >& linkingVars, vec<vec<long long int> >& linkingWeights){

	printf("c MRWTO encoding for Pseudo-Boolean Constraints\n");

	//CyouRyuu
	int CR1, CR2;
	long long int *weightsSort = new long long int[blockings.size()];
	for (CR1 = 0; CR1 < blockings.size(); ++CR1) {
		weightsSort[CR1] = weights[CR1];
	}
	quicksort(weightsSort, 0, blockings.size()-1);
	//upper bound (size limit)
	long long int sizeMax;
	if (k > pow(2, 12)) {
		sizeMax = pow(2, 12);
	} else {
		sizeMax = k;
	}
	printf("c sizeMax=%lld\n", sizeMax);
	/*
	//eratosthenes
	//sieve[n]=1 indicates that n is not prime; sieve[n]=0 indicates that n is prime.
	int *sieve = new int[sizeMax+1];
	for (CR1 = 0; CR1 < sizeMax+1; ++CR1) {
		sieve[CR1] = 0;
	}
	sieve[0] = sieve[1] = 1;
	int sqrt_MAX = sqrt(sizeMax);
	for (CR1 = 2; CR1 < sqrt_MAX; ++CR1) {
		if (!sieve[CR1]) {
			for (CR2 = CR1 * CR1; CR2 < sizeMax+1; CR2 += CR1) {
				sieve[CR2] = 1;
			}
		}
	}
	*/
	//natural number (>2)
	int *natural = new int[sizeMax+1];
	for (CR1 = 0; CR1 < sizeMax+1; ++CR1) {
		natural[CR1] = 0;
	}
	natural[0] = natural[1] = 1;
	//prime list completed
	
	bool pow1IsLastPrime = false;
	int nofDigits = 2;
	int nofDigitsPow1 = 2;
	int primePow1 = 0;
	long long int tmpCR = 0;
	int maxTime = 0;
	int prime = 0;
	int *topCount = new int[sizeMax+1];
	int *count = new int[sizeMax+1];
	while (weightsSort[blockings.size()-1] > 0) {
		//done and rest
		long long int tmProduct = 1;
		for (CR2 = 0; CR2 < divisors.size(); ++CR2) {
			tmProduct = tmProduct * divisors[CR2];
		}
		double restPart = (1.0 * k / tmProduct) + 1;
		//count 0 weights number
		int nofZero = 0;
		while (weightsSort[nofZero] == 0 && nofZero < blockings.size()) {
			nofZero++;
		}
		for (CR1 = 0; CR1 < sizeMax+1; ++CR1) {
			topCount[CR1] = 0;
		}
		for (CR1 = 0; CR1 < blockings.size(); ++CR1) {
			tmpCR = weightsSort[CR1];
			if (((divisors.size()==0 && tmpCR <= pow(2, 12)) || (divisors.size()<3 && tmpCR <= pow(2, 11)) || tmpCR <= pow(2, 10)) && tmpCR != 0) {
				if (CR1 == 0 || (CR1 > 0 && tmpCR != weightsSort[CR1-1])) {
					for (CR2 = 0; CR2 < sizeMax+1; ++CR2) {
						count[CR2] = 0;
					}
					while (tmpCR != 1) {
						for (CR2 = sizeMax; CR2 > 1; --CR2) {
							if (natural[CR2] == 0 && tmpCR % CR2 == 0) {	//natural[] <-> sieve[]
								tmpCR = tmpCR / CR2;
								count[CR2]++;
								break;
							}
						}
					}
				}
				for (CR2 = 2; CR2 < sizeMax+1; ++CR2) {
					//If you want to figure out <..> of (if(&& <..>)) below, please see naturNumbDivisor_v2.0 before or other versions
					//if (count[CR2] > 0 && divisors.size()+1 >= (log(k)/log(CR2))*(1-1/CR2)-(log(tmProduct)/log(CR2))) {
					if (count[CR2] > 0 && divisors.size()+1 >= (log(k)/log(CR2))/CR2) {
					//if (count[CR2] > 0) {
						topCount[CR2]++;
					}
				}
			}
		}
		bool nOkprmie = true;
		while (true) {
			if (!nOkprmie) {
				break;
			}
			maxTime = 0;
			for (CR1 = 2; CR1 < sizeMax+1; ++CR1) {
				if (topCount[CR1] > maxTime) {
					maxTime = topCount[CR1];
				}
			}
			if (maxTime == 0) {
				break;
			}
			for (CR1 = sizeMax; CR1 > 1; --CR1) {
				if (topCount[CR1] == maxTime && CR1 <= restPart && (log(restPart)/log(CR1))*maxTime > (blockings.size()-nofZero)) {
				//if (topCount[CR1] == maxTime && CR1 <= restPart && 2*maxTime >= (blockings.size()-nofZero)) {
					int tmpDivis, tdM, tdP;
					bool inM, inP;
					nofDigits = 2;
					for(long long int i = 256; i < restPart; i = i*16){
						nofDigits++;
					}
					tmpDivis = ((pow(restPart,(1.0/nofDigits))+1) < pow(max,(1.0/nofDigits)) ? (pow(restPart,(1.0/nofDigits))+1) : pow(max,(1.0/nofDigits)));
					if (CR1 > tmpDivis) {
						tdM = tmpDivis;	tdP = tmpDivis;
						inM = false;	inP = false;
						while (CR1 % tdM != 0 && tdM > 1) {
							tdM--;
						}
						if (tdM != 1)	inM = true;
						while (CR1 % tdP != 0 && tdP < CR1) {
							tdP++;
						}
						if (tdP != CR1)	inP = true;
						int dummyPrime = 1;
						if (inM && inP) {	//both are true
							dummyPrime = ((tmpDivis-tdM) <= (tdP-tmpDivis) ? tdM : tdP);
						} else if (inM && !inP) {	//only tdM is true
							dummyPrime = ((tmpDivis-tdM) <= (CR1-tmpDivis) ? tdM : CR1);
						} else if (!inM && inP) {	//only tdP is true
							dummyPrime = tdP;
						} else {	//both are false
							dummyPrime = CR1;
						}
						prime = dummyPrime;
					} else {
						prime = CR1;
					}
					printf("c No.%d Divisor=%d\tmaxTime=%d\tnofZero=%d\tdRate=%.2f\%\tEvl=%.2f\n", divisors.size(), prime, maxTime, nofZero, 100.0*maxTime/(blockings.size()-nofZero), log(k)/log(CR1)/CR1);
					nOkprmie = false;
					pow1IsLastPrime = false;
					break;
				} else {
					topCount[CR1] = 0;
				}
			}
		}
		if (nOkprmie) {
			if (divisors.size() != 0 && restPart < divisors[0]*divisors[0]) {
				prime = divisors[0];
			} else {
				nofDigits = 2;
				for(long long int i = 256; i < restPart; i = i*16){
					nofDigits++;
				}
				prime = ((pow(restPart,(1.0/nofDigits))+1) < pow(max,(1.0/nofDigits)) ? (pow(restPart,(1.0/nofDigits))+1) : pow(max,(1.0/nofDigits)));
			}
			if (prime <= 1) {
				printf("c Divisor can not be less than 2 (pow1)\n");
			} else {
				printf("c No.%d Divisor=%d\tgenerated by pow1\n", divisors.size(), prime);
				nofDigitsPow1 = nofDigits;
				primePow1 = prime;
				pow1IsLastPrime = true;
			}
		}
		if (prime <= 1) {
			break;
		}
		divisors.push(prime);
		for (CR1 = 0; CR1 < blockings.size(); ++CR1) {
			weightsSort[CR1] = weightsSort[CR1] / prime;
		}
		quicksort(weightsSort, 0, blockings.size()-1);
		prime = 0;
	}
	
	long long int productPrime = 1;
	if (card == 11){
		for(int CRk=0; CRk < divisors.size(); ++CRk){
			long long int in2Divisors = divisors[CRk];
			productPrime = productPrime * in2Divisors;
		}
	}
	if (productPrime < k) {
		if (pow1IsLastPrime) {
			for(int CRk = 0; CRk < nofDigitsPow1-2; CRk++){
				printf("c No.%d Divisor=%d\tgenerated by pow1\n", divisors.size(), primePow1);
				divisors.push(primePow1);
			}
		} else {
			double restPart = (1.0 * k / productPrime) + 1;
			nofDigits = 2;
			for(long long int i = 256; i < restPart; i = i*16){
				nofDigits++;
			}
			prime = ((pow(restPart,(1.0/nofDigits))+1) < pow(max,(1.0/nofDigits)) ? (pow(restPart,(1.0/nofDigits))+1) : pow(max,(1.0/nofDigits)));
			for(int CRk = 0; CRk < nofDigits-1; CRk++){
				printf("c No.%d Divisor=%d\tgenerated by pow2\n", divisors.size(), prime);
				divisors.push(prime);
			}
		}
	}
	
	printf("c ");
	for(int CRk=0; CRk < divisors.size(); ++CRk) {
		printf("p%d= %lld\t" ,CRk, divisors[CRk]);
	}
	printf("\n");
	if(card == 11) {
		printf("c number of digits = %d\n",divisors.size()+1);
	}
	
	//linkingVars,linkingWeightSのサイズの設定
	for(int i=0;i<divisors.size()+1;i++){
		linkingVars.push();
		linkingWeights.push();
	}

	vec<long long int> weightsTable;
	long long int tmp = 0;
	int size = blockings.size();

	for(int i = 0 ; i < size ; ++i){

		tmp += weights[i];
		weightsTable.push(tmp);
	}

	Lit zero = mkLit(S.newVar());
	lits.clear();
	lits.push(zero);
	S.addClause_(lits);

	Var varZero = var(zero);

	genMRWTO(weights ,blockings , weightsTable , 0, size-1 ,divisors,
			zero, linkingVars , linkingWeights , S , k,lits,varZero);
}



// koshi 2013.04.05, 2013.05.21, 2013.06.28, 2013.07.01, 2013.10.04
// koshi 20140121
void genCardinals(int& card, int comp,
		  vec<long long int>& weights, vec<Lit>& blockings,
		  long long int max, long long int k,
		  long long int& divisor, // koshi 2013.10.04
		  Solver& S, vec<Lit>& lits, vec<Lit>& linkingVar,vec<long long int>& linkingWeight, //uemura 20161202
		  vec<long long int>& divisors, //uemura 20161128
		  vec<vec<Lit> >& linkingVars,vec<vec<long long int> >& linkingWeights) { //uemura 20161128
  assert(weights.size() == blockings.size());

  vec<long long int> sweights;
  vec<Lit> sblockings;
  wbSort(weights,blockings, sweights,sblockings);
  wbFilter(k,S,lits, sweights,sblockings, weights,blockings);

  long long int sum = sumWeight(weights); // koshi 20140124
  printf("c Sum of weights = %lld\n",sum);
  printf("c A number of soft clauses remained = %d\n",blockings.size());

  if (card == -1) { // koshi 20140324 auto mode
    printf("c auto-mode for generating cardinality constraints\n");
    int logk = 0;
    int logsum = 0;
    for (long long int ok = k; ok > 0; ok = ok >> 1) logk++;
    for (long long int osum = sum; osum > 0; osum = osum >> 1) logsum++;
    printf("c logk = %d, logsum = %d\n",logk,logsum);
    if (logk+logsum < 15) {
      // Bailleux
      card = 1; comp = 0;
      printf("c Bailleux's encoding (comp=0)\n");
    } else if (k < 3) {// Warners
      card = 0; comp = 1;
      printf("c Warners' encoding (comp=1)\n");
    } else if (logsum < 17) {// Ogawa
      card = 3; comp = 0;
      printf("c Ogawa's encoding (comp=0)\n");
    } else {
      card = 0; comp = 1;
      printf("c Warners' encoding (comp=1)\n");
    }

  }

  if (weights.size() == 0) {linkingVar.clear();} else // koshi 20140124 20140129
  // koshi 2013.06.28
  if (card == 0) // Warners
    genWarners0(weights,blockings, max,k, comp, S, lits,linkingVar);
  else if (card == 1) // Bailleux
    genBailleux0(weights,blockings, max,k, comp, S, lits,linkingVar);
  else if (card == 2) // Asin
    genAsin(weights,blockings, max,k, comp, S, lits,linkingVar);
  else if (card == 3) // Ogawa
    genOgawa0(card, // koshi 2013.12.24
	      weights,blockings, max,k,divisor, comp, S, lits,linkingVar);
  else if (card == 6) // BailleuxW2 k cardinal hayata 2015/02/06
  	genBailleuxW20(weights,blockings, max,k, comp, S, lits,linkingVar , linkingWeight);

  else if (card == 10){//WMTO uemura 2016.11.29
	genKWMTO0(card,weights,blockings,max,k,divisors,S,lits,linkingVars,linkingWeights);
  }
  else if (card == 11 || card == 12){//MRWTO uemura 2016.11.29
	genMRWTO0(card,
	      weights,blockings ,max,k,divisors, S, lits, linkingVars , linkingWeights );
  }
  sweights.clear(); sblockings.clear();
}

// koshi 13.04.05, 13.06.28, 13.07.01, 13.10.04
void lessthan(int card, vec<Lit>& linking,vec<long long int>& linkingWeight, long long int ok, long long int k,
	      long long int divisor, // koshi 13.10.04
	      vec<long long int>& cc, Solver& S, vec<Lit>& lits) { //, vec<Lit>& assumps) {
  assert(k > 0);
  if (linking.size() == 0) {} else // koshi 20140124 20140129
  if (card == 1) {// Bailleux encoding (Totalizer)
    for (long long int i = k;
	 i < linking.size() && i < ok; i++) {
      lits.clear();
      lits.push(~linking[i]);
      //lits.push(~assumps[k-1]); // Anonymous1 20181220 for incremental maxsat
      S.addClause_(lits);
    }
  } else if (card == 2) {// Asin encoding
    for (long long int i = k-1;
	 i < linking.size() && i < ok; i++) {
      lits.clear();
      lits.push(~linking[i]);
      //lits.push(~assumps[k-1]); // Anonymous1 20181220 for incremental maxsat
      S.addClause_(lits);
    }

  }else if (card == 6) {//Weighted  Bailleux encoding (Weighted Totalizer) hayata 2014/12/17

		for (long long int i = 1 ; i < linking.size() ; i++) {
			long long int tmp_w = linkingWeight[i];
			if(tmp_w >= k && tmp_w < ok){
				lits.clear();
				lits.push(~linking[i]);
				//lits.push(~assumps[k-1]); // Anonymous1 20181220 for incremental maxsat
				S.addClause_(lits);
				//if(S.verbosity > 1)
				//	printf("[%lld]\n" , tmp_w);
			}
			//printf("[-%d]" , var(lits[0])+1);
		}
  }
  else if (card == 3) {// Ogawa encoding (Modulo Totalizer)
    long long int upper = (k-1)/divisor;
    long long int lower = k%divisor;
    long long int oupper = ok/divisor;
    //    printf("upper = %lld, oupper = %lld\n", upper,oupper);
    if (upper < oupper)
      for (long long int i = divisor+upper+1; i < divisor+oupper+1; i++) {
	if (linking.size() <= i) break;
	else {
	  //	  printf("linking i = %lld ",i);
	  lits.clear();
	  lits.push(~linking[i]);
	  //lits.push(~assumps[k-1]); // Anonymous1 20181220 for incremental maxsat
	  S.addClause_(lits);
	}
      }
    upper = k/divisor;
    lits.clear();
    lits.push(~linking[divisor+upper]);
    lits.push(~linking[lower]);
    //lits.push(~assumps[k-1]); // Anonymous1 20181220 for incremental maxsat
    //    printf("divisor+upper = %lld, lower = %lld\n",divisor+upper,lower);
    S.addClause_(lits);
  } else if (card == 0) {// Warners encoding
    vec<long long int> cls;
    cls.clear();

    k--;
    if (k%2 == 0) cls.push(1);
    k = k/2;
    int cnt = 1;
    long long int pos = 0x0002LL;
    while (k > 0) {
      if (k%2 == 0) cls.push(pos);
      //    else if (cls.size() == 0) cls.push(pos);
      else for(int i = 0; i < cls.size(); i++) cls[i] = cls[i] | pos;
      pos = pos << 1;
      k = k/2;
      cnt++;
    }
    for(int i = cnt; i < linking.size(); i++) {
      cls.push(pos);
      pos = pos << 1;
    }
    for(int i = 0; i < cls.size(); i++) {
      long long int x = cls[i];
      bool found = false;
      for(int j = 0; j < cc.size(); j++) {
	if (x == cc[j]) {
	  found = true; break;
	}
      }
      if (!found) {
	cc.push(x); // koshi 2013.10.04
	lits.clear();
	int j = 0;
	while (x > 0) {
	  if ((x & 0x0001L) == 0x0001L) {
	    lits.push(~linking[j]);
	  }
	  x = x >> 1;
	  j++;
	}
	S.addClause_(lits);
      }
    }
  }
}

//uemura 20161128
void lessthanMR(int card, vec<vec<Lit> >& linkings, vec<vec<long long int> >& linkingWeights,
		long long int ok, long long int k, vec<long long int>& divisors,
		vec<long long int>& cc, Solver& S, vec<Lit>& lits) { //, vec<Lit>& assumps) {

	assert(k > 0);

	if (linkings[0].size() == 0) {} else {// uemura 20161112
		int ndigit = linkings.size();
		long long int tmp_k = k;
		long long int tmp_ok = ok;
		//okは前回のk

		vec<Lit> control;

		//各桁を計算して表示する
		int *sp_k = new int[ndigit];
		int *sp_ok = new int[ndigit];
		for(int i = 0;i<ndigit-1;i++){
			sp_k[i] = tmp_k % divisors[i];
			sp_ok[i] = tmp_ok % divisors[i];
			tmp_k = tmp_k / divisors[i];
			tmp_ok = tmp_ok / divisors[i];
		}
		sp_k[ndigit-1] = tmp_k;
		sp_ok[ndigit-1] = tmp_ok;

		printf("c k = %lld(",k);
		for(int i = ndigit-1;i>=0;i--){
			printf("%d/",sp_k[i]);
		}
		printf("\b)");
		for(int i=ndigit-2;i>=0;i--){
			printf(" p%d = %lld ",i,divisors[i]);
		}
		printf("\n");

		/* 自分より下の桁が全て0である場合、自分の否定も問題に加える
		 * そうでない場合は、自分より大きなものの否定を問題に加える。
		 */
		for(int i=ndigit-1;i>=0;i--){
			int cnr_k = 0;
			int cnr_ok = 0;
			for(int k = 0;k<i;k++){
				if(sp_k[k]>0) {cnr_k=1;}
				if(sp_ok[k]>0){cnr_ok=1;}
			}
			if(cnr_k == 1) {sp_k[i]++;}
			if(cnr_ok == 1){sp_ok[i]++;}
		}

		for(int cdigit = ndigit-1; cdigit>=0; cdigit--){
			int checknextdigit = 0;
			int sp_k2 = -1;
			long long int tmp_max = 0;
			//現在の桁より下の桁がすべて0出ないことのチェック
			for(int i = cdigit-1;i>=0;i--){
				if(sp_k[i] > 0){
					checknextdigit=1;
				}
			}
			//最上位桁の処理=======================================================================================================
			if(cdigit == ndigit-1){
				if (linkings[cdigit].size() == 0) {
					fprintf(stderr , "ERROR : link size digit[%d] = 0\t@less thanMR\n",cdigit);
					exit(1);
				} else {// uemura 20161112

					for (long long int i = 1 ; i < linkings[cdigit].size() ; i++) {
						if(linkingWeights[cdigit][i] >= sp_k[cdigit]){
							if(linkingWeights[cdigit][i] <sp_ok[cdigit]){//tmp_ok=>sp_ok
								lits.clear();
								lits.push(~linkings[cdigit][i]);
								//lits.push(~assumps[k-1]); // Anonymous1 20181221 for incremental maxsat
								S.addClause_(lits);
							}
						}else if(checknextdigit == 1){
							if(tmp_max < linkingWeights[cdigit][i]){
								tmp_max = linkingWeights[cdigit][i];
								sp_k2 = i;
							}
						}
					}
					if(sp_k[cdigit] > 1 && sp_k2 > 0){
						control.push(~linkings[cdigit][sp_k2]);
					}
				}
			}

			else if (cdigit  >=0){
			//最上位より下の桁の処理================================================================================================-
				if (linkings[cdigit].size() == 0) {
					fprintf(stderr , "ERROR : link size digit[%d] = 0\t@less thanMR\n",cdigit);
					exit(1);
				} else if(sp_k[cdigit] > 0) {// uemura 20161112
					for (long long int i = 1 ; i < linkings[cdigit].size() ; i++) {
						if(linkingWeights[cdigit][i] >= sp_k[cdigit]){
							lits.clear();
							for(int ctr = 0 ; ctr < control.size() ; ++ctr){
								lits.push(control[ctr]);
							}
							lits.push(~linkings[cdigit][i]);
							//lits.push(~assumps[k-1]); // Anonymous1 20181221 for incremental maxsat
							S.addClause_(lits);
						}
						else if(checknextdigit == 1){
							if(tmp_max < linkingWeights[cdigit][i]){
								tmp_max = linkingWeights[cdigit][i];
								sp_k2 = i;
							}
						}
					}
					if(sp_k2 > 0){
						control.push(~linkings[cdigit][sp_k2]);
					}else{
						control.push(~linkings[cdigit][0]);
					}
				}
			}
		}
		control.clear();
		delete []sp_k;
		delete []sp_ok;
	}
}


//=================================================================================================
// Main:


int main(int argc, char** argv)
{
    try {
        setUsageHelp("USAGE: %s [options] <input-file> <result-output-file>\n\n  where input may be either in plain or gzipped DIMACS.\n");
        // printf("This is MiniSat 2.0 beta\n");

	printf("c This is QMaxSAT 2018 (Constraints Journal Version)\n");
	printf("c This is Glucose 3.0\n");
	printf("c This is MiniSat 2.2.0\n");

#if defined(__linux__)
        fpu_control_t oldcw, newcw;
        _FPU_GETCW(oldcw); newcw = (oldcw & ~_FPU_EXTENDED) | _FPU_DOUBLE; _FPU_SETCW(newcw);
        printf("c WARNING: for repeatability, setting FPU to use double precision\n");
#endif
        // Extra options:
        //
        IntOption    verb   ("MAIN", "verb",   "Verbosity level (0=silent, 1=some, 2=more).", 0, IntRange(0, 2));
        IntOption    cpu_lim("MAIN", "cpu-lim","Limit on CPU time allowed in seconds.\n", INT32_MAX, IntRange(0, INT32_MAX));
        IntOption    mem_lim("MAIN", "mem-lim","Limit on memory usage in megabytes.\n", INT32_MAX, IntRange(0, INT32_MAX));
	// koshi 20140106
	/*
        IntOption    card   ("MAIN", "card",   "Type of SAT-encodings for Cardinality Constraints", 0, IntRange(0, 3));
	// 0: [Warners 1998]
	// 1: [Bailleux & Boufkhad 2003]
	// 2: [Asin et. al 2011]
	// 3: [Ogawa et. al 2013]
	// -1: auto // koshi 20140324
	*/
        StringOption cardS   ("MAIN", "card",   "Type of SAT-encodings for Cardinality Constraints\n           warn, bail, asin, ogaw, wmto, mrwto, and auto", "auto");

        IntOption    comp   ("MAIN", "comp",
			     "Variants of SAT-encodings for Cardinality Constraints\n          warn -> 0,1,2,10,11,   bail -> 0,10,11,\n          asin -> 0,10,11,    ogaw -> 0,   wmto -> 0,   mrwto -> 0",
			     0, IntRange(0, 11));
	// koshi 20150629 for evaluation
        IntOption    pmodel   ("MAIN", "pmodel",   "Print a MaxSAT model", 1, IntRange(0, 1));
	// cyouryuu 20181214 for incremental
	IntOption    incr   ("MAIN", "incr",   "Incremental model", 1, IntRange(0, 1));

        parseOptions(argc, argv, true);

	int card;
	printf("c card = ");
	if (strcmp(cardS, "warn") == 0) {
	  printf("warn, "); card = 0;
	}
	if (strcmp(cardS, "bail") == 0)  {
	  printf("bail, "); card = 1;
	}
	if (strcmp(cardS, "asin") == 0) {
	  printf("asin, "); card = 2;
	}
	if (strcmp(cardS, "ogaw") == 0) {
	  printf("ogaw, "); card = 3;
	}
	if (strcmp(cardS, "bailw2") == 0) {
			  printf("bailw2, "); card = 6;
		}

	if (strcmp(cardS, "wmto") == 0) {
		  printf("wmto, "); card = 10;
	}
	if (strcmp(cardS, "mrwto") == 0) {
		  printf("mrwto, "); card = 11;
	}
	if (strcmp(cardS, "mrwto2") == 0) {
			  printf("mrwto2, "); card = 12;
		}
	if (strcmp(cardS, "auto") == 0) {
	  printf("auto, "); card = -1;
	}
	printf("comp = %d, pmodel = %d, incr = %d, verb = %d\n",
	       (int) comp,(int) pmodel,(int) incr,(int) verb);

        Solver S;
        double initial_time = cpuTime();

        S.verbosity = verb;

        solver = &S;
        // Use signal handlers that forcibly quit until the solver will be able to respond to
        // interrupts:
        signal(SIGINT, SIGINT_exit);
        signal(SIGXCPU,SIGINT_exit);

        // Set limit on CPU-time:
        if (cpu_lim != INT32_MAX){
            rlimit rl;
            getrlimit(RLIMIT_CPU, &rl);
            if (rl.rlim_max == RLIM_INFINITY || (rlim_t)cpu_lim < rl.rlim_max){
                rl.rlim_cur = cpu_lim;
                if (setrlimit(RLIMIT_CPU, &rl) == -1)
                    printf("WARNING! Could not set resource limit: CPU-time.\n");
            } }

        // Set limit on virtual memory:
        if (mem_lim != INT32_MAX){
            rlim_t new_mem_lim = (rlim_t)mem_lim * 1024*1024;
            rlimit rl;
            getrlimit(RLIMIT_AS, &rl);
            if (rl.rlim_max == RLIM_INFINITY || new_mem_lim < rl.rlim_max){
                rl.rlim_cur = new_mem_lim;
                if (setrlimit(RLIMIT_AS, &rl) == -1)
                    printf("WARNING! Could not set resource limit: Virtual memory.\n");
            } }

        if (argc == 1)
            printf("Reading from standard input... Use '--help' for help.\n");

        gzFile in = (argc == 1) ? gzdopen(0, "rb") : gzopen(argv[1], "rb");
	// Anonymous1 20181217 for reading an input file of externality
	// -> begin Anonymous1
	FILE * exIn;
	char * line = NULL;
	size_t len = 0;
	ssize_t read;
	if (argc >= 4) exIn = fopen(argv[2], "r");
	if (exIn == NULL) exit(EXIT_FAILURE);
	
	int nofBus;
	int newDemandSize;
	vector<int> acceptedSizeArray;
	vector<int> gridStartIndex;
	vector<vector<int>> deadlineArray;
	vector<int> nofCarried;
	vector<vector<int>> pickDropArray;
	vector<int> capacityArray;
	vector<vector<int>> dummyArray;
	vector<int> dummyOrder;
	vector<int> keepAuxVar;
	vector<string> tmpStrVec;
	vector<int> tmpIntVec;

	vector<int> allPositiVec;
	vector<bool> fullIndexArray;
	vector<vector<int>> chainsArray;
	vector<vector<int>> AnsChainsArray;
	vector<int> tmpChain;
	int avgNofAccepted = 0;
	bool needBlock;
	bool reasonIsCapacity;
	while ((read = getline(&line, &len, exIn)) != -1) {
		int nextStartIndex;
		string str = line;
		tmpStrVec.clear();
		if (str.find("nofBus") != string::npos) {
			nofBus = stoi(str.erase(0, 7));
			cout << "cr nofBus: " << nofBus << "\n";
		} else if (str.find("newDemandSize") != string::npos) {
			newDemandSize = stoi(str.erase(0, 14));
			cout << "cr newDemandSize: " << newDemandSize << "\n";
		} else if (str.find("acceptedSizeArray") != string::npos) {
			tmpStrVec = split(str.erase(0, 18), ' ');
			int tmpSum = 0;
			for (int i=0; i<tmpStrVec.size(); i++) {
				acceptedSizeArray.push_back(stoi(tmpStrVec[i]));
				tmpSum = tmpSum + stoi(tmpStrVec[i]);
			}
			avgNofAccepted = tmpSum / nofBus;
			cout << "cr acceptedSizeArray:";
			for (int i=0; i<acceptedSizeArray.size(); i++) 
				cout << " " << acceptedSizeArray[i];
			cout << "\n";
		} else if (str.find("gridStartIndex") != string::npos) {
			tmpStrVec = split(str.erase(0, 15), ' ');
			for (int i=0; i<tmpStrVec.size(); i++)
				gridStartIndex.push_back(stoi(tmpStrVec[i]));
			cout << "cr gridStartIndex:";
			for (int i=0; i<gridStartIndex.size(); i++) 
				cout << " " << gridStartIndex[i];
			cout << "\n";
		} else if (str.find("deadlineArray") != string::npos) {
			tmpStrVec = split(str.erase(0, 14), ' ');
			nextStartIndex = 0;
			for (int i=0; i<nofBus; i++) {
				tmpIntVec.clear();
				for (int j=nextStartIndex; j<nextStartIndex+acceptedSizeArray[i]+2*newDemandSize; j++)
					tmpIntVec.push_back(stoi(tmpStrVec[j]));
				deadlineArray.push_back(tmpIntVec);
				nextStartIndex = nextStartIndex + tmpIntVec.size();
			}
			cout << "cr deadlineArray:";
			for (int i=0; i<deadlineArray.size(); i++) {
				for (int j=0; j<deadlineArray[i].size(); j++)
					cout << " " << deadlineArray[i][j];
			}
			cout << "\n";
		} else if (str.find("nofCarried") != string::npos) {
			tmpStrVec = split(str.erase(0, 11), ' ');
			for (int i=0; i<tmpStrVec.size(); i++)
				nofCarried.push_back(stoi(tmpStrVec[i]));
			cout << "cr nofCarried:";
			for (int i=0; i<nofCarried.size(); i++) 
				cout << " " << nofCarried[i];
			cout << "\n";
		} else if (str.find("pickDropArray") != string::npos) {
			tmpStrVec = split(str.erase(0, 14), ' ');
			nextStartIndex = 0;
			for (int i=0; i<nofBus; i++) {
				tmpIntVec.clear();
				for (int j=nextStartIndex; j<nextStartIndex+acceptedSizeArray[i]+2*newDemandSize; j++)
					tmpIntVec.push_back(stoi(tmpStrVec[j]));
				pickDropArray.push_back(tmpIntVec);
				// cout << "nexStaIdx: " << nextStartIndex << " tmpSiz: " << tmpIntVec.size() << " \n";
				nextStartIndex = nextStartIndex + tmpIntVec.size();
			}
			cout << "cr pickDropArray:";
			for (int i=0; i<pickDropArray.size(); i++) {
				for (int j=0; j<pickDropArray[i].size(); j++)
					cout << " " << pickDropArray[i][j];
			}
			cout << "\n";
		} else if (str.find("capacityArray") != string::npos) {
			tmpStrVec = split(str.erase(0, 14), ' ');
			for (int i=0; i<tmpStrVec.size(); i++)
				capacityArray.push_back(stoi(tmpStrVec[i]));
			cout << "cr capacityArray:";
			for (int i=0; i<capacityArray.size(); i++) 
				cout << " " << capacityArray[i];
			cout << "\n";

		} else if (str.find("dummyArray") != string::npos) {
			tmpStrVec = split(str.erase(0, 11), ' ');
			nextStartIndex = 0;
			for (int i=0; i<nofBus; i++) {
				tmpIntVec.clear();
				for (int j=nextStartIndex; j<nextStartIndex+acceptedSizeArray[i]+2*newDemandSize; j++)
					tmpIntVec.push_back(stoi(tmpStrVec[j]));
				dummyArray.push_back(tmpIntVec);
				nextStartIndex = nextStartIndex + tmpIntVec.size();
			}
			cout << "cr dummyArray:";
			for (int i=0; i<dummyArray.size(); i++) {
				for (int j=0; j<dummyArray[i].size(); j++)
					cout << " " << dummyArray[i][j];
			}
			cout << "\n";

		} else if (str.find("dummyOrder") != string::npos) {
			tmpStrVec = split(str.erase(0, 11), ' ');
			for (int i=0; i<tmpStrVec.size(); i++)
				dummyOrder.push_back(stoi(tmpStrVec[i]));
			cout << "cr dummyOrder:";
			for (int i=0; i<dummyOrder.size(); i++) 
				cout << " " << dummyOrder[i];
			cout << "\n";
		} else if (str.find("keepAuxVar") != string::npos) {
			tmpStrVec = split(str.erase(0, 11), ' ');
			for (int i=0; i<tmpStrVec.size(); i++)
				keepAuxVar.push_back(stoi(tmpStrVec[i]));
			cout << "cr keepAuxVar:";
			for (int i=0; i<keepAuxVar.size(); i++) 
				cout << " " << keepAuxVar[i];
			cout << "\n";
		}
	}
	fclose(exIn);
	if (line) free(line);
	// <- end Anonymous1
        if (in == NULL)
            printf("ERROR! Could not open file: %s\n", argc == 1 ? "<stdin>" : argv[1]), exit(1);

        if (S.verbosity > 0){
            printf("============================[ Problem Statistics ]=============================\n");
            printf("|                                                                             |\n"); }

	// koshi 20140107
	int nbvar  = 0; // number of original variables
	/* weight of hard clause
	   0 indicates ms (unweighted MaxSAT)
	     i.e. all clauses are 1-weighted soft clauses
	   -1 indicates wms (weighted MaxSAT)
	     i.e. all clauses are weighted soft clauses
	   positive value indicates pms or wpms (partial MaxSAT)
	 */
	long long int top    = 0;
	int nbsoft = 0; // number of soft clauses
	vec<long long int> weights;
	vec<Lit> blockings;

	parse_DIMACS(in, S, nbvar, top, nbsoft, weights,blockings);
	//	printf("top = %d\n",top);
	//        parse_DIMACS(in, S);
        gzclose(in);
	// Anonymous1 20181217 for modification of the writeOut UNSAT prooFile
        FILE* res = (argc >= 5) ? fopen(argv[4], "wb") : NULL;

        if (S.verbosity > 0){
            printf("|  Number of variables:  %12d                                         |\n", S.nVars());
            printf("|  Number of clauses:    %12d                                         |\n", S.nClauses()); }

        double parsed_time = cpuTime();
        if (S.verbosity > 0){
            printf("|  Parse time:           %12.2f s                                       |\n", parsed_time - initial_time);
            printf("|                                                                             |\n"); }

        // Change to signal-handlers that will only notify the solver and allow it to terminate
        // voluntarily:
        signal(SIGINT, SIGINT_interrupt);
        signal(SIGXCPU,SIGINT_interrupt);

        if (!S.simplify()){
            if (res != NULL) fprintf(res, "UNSAT\n"), fclose(res);
            if (S.verbosity > 0){
                printf("===============================================================================\n");
                printf("Solved by unit propagation\n");
                printStats(S);
                printf("\n"); }
            printf("UNSATISFIABLE\n");
            exit(20);
        }

	// koshi 20140107
	long long int answer = sumWeight(weights);
	// Anonymous1 save the firstAns
	long long int firstAns = answer;

	/* koshi 20140404
	if (card == 3 && answer < TOTALIZER) {
	  card = 1;
	  printf("c Sum of weights is %lld, ", answer);
	  printf("which is small, so we use normal totalizer, i.e. -card=bail\n");
	}
	*/

	vec<Lit> lits;
	int lcnt = 0; // loop count
	vec<Lit> linkingVar;
	vec<long long int> linkingWeight; //uemura 20161202
	//bool mmodel[nbvar]; // koshi 2013.07.05
	bool *mmodel = new bool[nbvar]; //uemura 20161128
	long long int divisor = 1; // koshi 2013.10.04

	vec<long long int> ndivisor;//mrwto用の複数の基数を保存する変数 uemura 2016.12.05
	vec<vec<Lit> > linkingVarMR; //uemura 2016.12.05 for mrwto
	vec<vec<long long int> > linkingWeightMR;//uemura 2016.12.05 for mrwto

	vec<long long int> cc; // cardinality constraints
	cc.clear();
	// Anonymous1 20181220 for incremental maxsat
	long long int currentMinAns = answer;
	/* Anonymous1 20190125 remove 'assumps'
	vec<Lit> assumps;
	for (int i=0; i<firstAns; i++) {
		Lit lit = mkLit(S.newVar());
		assumps.push(lit);
	}
	*/
	// Anonymous1 20190204 for dummy
	int nextIdx = 0;
	bool goDummy = false;
	bool removeKeep = false; // not used yet!
        vec<Lit> dummy;

	// koshi 20140701        lbool ret = S.solveLimited(dummy);
	lbool ret;

	for (int i=0; i<dummyArray.size(); i++) {
		dummy.clear();
		for (int j=0; j<dummyArray[i].size(); j++) {
			dummy.push(mkLit((Var) dummyArray[i][j], false));
		}
		ret = S.solveLimited(dummy);
		if (ret == l_True) { goDummy = true; nextIdx = i+1; break; }
		if (i == dummyArray.size()-1) dummy.clear();
	}

	while (ret == l_True || lcnt == 0) {// koshi 20140107
	  dummy.clear();
	  /*
	  if (lcnt > 0 && nextIdx < nofBus) {
		  for (int i=0; i<dummyArray[nextIdx].size(); i++) {
			  dummy.push(mkLit((Var) dummyArray[nextIdx][i], false));
		  }
		  nextIdx++;
	  }
	  */
	  if (goDummy) goDummy = false;
	  else {
		  if ( AnsChainsArray.size() == 0 || avgNofAccepted > 2*capacityArray[0] ) {
			  for (int i=0; i<keepAuxVar.size(); i++) {
				  dummy.push(mkLit((Var) keepAuxVar[i], false));
			  }
		  } else {
			  for (int i=0; i<keepAuxVar.size(); i++) {
				  dummy.push(mkLit((Var) keepAuxVar[i], true));
			  }
		  }
		  ret = S.solveLimited(dummy);
	  }
	  if (ret == l_False) cout << "Hard clauses = UNSAT\n";
	  lcnt++;
	  long long int answerNew = 0;
	  needBlock = false;
	  reasonIsCapacity = false;

	  for (int i = 0; i < blockings.size(); i++) {
	    int varnum = var(blockings[i]);
	    if (sign(blockings[i])) {
	      if (S.model[varnum] == l_False) {
		answerNew += weights[i];
	      }
	    } else {
	      if (S.model[varnum] == l_True) {
		answerNew += weights[i];
	      }
	    }
	  }
	  printf("o %lld | cpuTime %g s\n",answerNew, cpuTime());
	  if (lcnt > 1) assert(currentMinAns <= answer); // Anonymous1 20190104 for incremental maxsat
	  if (lcnt == 1) { // first model: generate cardinal constraints
	    int nvars = S.nVars();
	    int ncls = S.nClauses();

	    //genCardinals(card,comp, weights,blockings, answer,answerNew,divisor,
	    //	 S, lits, linkingVar);
	    // uemura 20161128
	    genCardinals(card,comp, weights,blockings, answer,answerNew,divisor,
			 S, lits, linkingVar,linkingWeight,ndivisor,linkingVarMR , linkingWeightMR);
	    //printf("c linkingVar.size() = %d\n",linkingVar.size());
	    //uemura 20161129
	    if (card < 10){
	    printf("c linkingVar.size() = %d\n",linkingVar.size());
	    }else if (card == 10 || card == 11 || card == 12){
	    	printf("c ");
	    	for(int i = 0;i<linkingVarMR.size();i++){
	    		printf("linkingVar[%d].size = %d, ",i,linkingVarMR[i].size());
	    	}
	    	printf("\n");
	    }
	    printf("c Pseudo-Boolean Constraints: %d variables and %d clauses\n",
		S.nVars()-nvars,S.nClauses()-ncls);
	  }
	  if (pmodel == 1) {
	    for (int i = 0; i < nbvar; i++) {
	      if (S.model[i]==l_True)
		mmodel[i] = true;
	      else mmodel[i] = false;
	    }
	  }
	  if (answerNew > 0) {
		  // Anonymous1 for incremental maxsat
		  if (incr == 1) {
			  /*
			  for (int i = 0; i < nbvar; i++)
 				  if (S.model[i] != l_Undef)
					  printf("%s%s%d", (i==0)?"":" ", (S.model[i]==l_True)?"":"-", i+1);
			  printf("\n");
			  */
			  allPositiVec.clear();
			  fullIndexArray.clear();
			  chainsArray.clear();
			  for (int i=0; i<nbvar; i++) {
				  if (S.model[i] != l_Undef && S.model[i]==l_True) allPositiVec.push_back(i+1);
			  }
			  /*
			  printf ("positv -> ");
			  for (int i=0; i<allPositiVec.size(); i++) {
				  printf ("%d ", allPositiVec[i]);
			  }
			  printf("\n");
			  */
			  for (int i=0; i<nbvar; i++) fullIndexArray.push_back(false);
			  for (int i=0; i<allPositiVec.size(); i++)
				  fullIndexArray[allPositiVec[i]-1] = true;
			  for (int h=0; h<nofBus; h++) {
				  tmpChain.clear();
				  for (int y=1; y<=(acceptedSizeArray[h]+2*newDemandSize); y++) {
					  int tmpIdxInRange = (y-1)*(acceptedSizeArray[h]+2*newDemandSize+1)+gridStartIndex[h];
					  if (fullIndexArray[tmpIdxInRange-1]) {
						  tmpChain.push_back(tmpIdxInRange);
						  chainSorter(tmpIdxInRange, acceptedSizeArray[h]+2*newDemandSize, gridStartIndex[h]-1, tmpChain, fullIndexArray);
						  break;
					  }
				  }
				  chainsArray.push_back(tmpChain);
			  }
			  printf("chain: [ | ");
			  for (int i=0; i<chainsArray.size(); i++) {
				  for (int j=0; j<chainsArray[i].size(); j++) printf("%d ", chainsArray[i][j]);
				  printf("| ");
			  }
			  printf("]\n");
			  // for (int i=0; i<weights.size(); i++) cout << weights[i] << " "; printf("\n");
			  // check deadline violation
			  long long int sumDelay;
			  int sumCarry;
			  vector<int> dummyBlock;
			  int weightIdxPlus = 0;
			  for (int i=0; i<nofBus && !needBlock; i++) {
				  if (chainsArray[i].size()-2 == acceptedSizeArray[i]) {
					  //cout << "i : " << i << " | chainsArray[i].size() : " << chainsArray[i].size() << " | acceptedSizeArray[i] : " << acceptedSizeArray[i] << "\n";
					  sumDelay = 0;
					  sumCarry = nofCarried[i];
					  dummyBlock.clear();
					  weightIdxPlus = (i==0)?0:(weightIdxPlus+(acceptedSizeArray[i-1]+2*newDemandSize)*(acceptedSizeArray[i-1]+2*newDemandSize+1));
					  for (int j=0; j<chainsArray[i].size(); j++) {
						  int deadline = 0;
						  int currentPath = chainsArray[i][j];
						  int toColumn = fromTo(currentPath, acceptedSizeArray[i]+2*newDemandSize, gridStartIndex[i]-1)-(gridStartIndex[i]-1);
						  sumDelay = sumDelay + weights[currentPath-gridStartIndex[i]+weightIdxPlus];
						  dummyBlock.push_back(currentPath);
						  deadline = deadlineArray[i][toColumn-2];
						  // cout << "busIdx: " << i << " | cp: " << currentPath << " | toCol: " << toColumn << " | dl: " << deadline << "\n";
						  if (deadline > 0) {
							  if (sumDelay > deadline) {
								  needBlock = true;
								  cout << "block (reason: exceeDeadline [pos]) -> cp: " << currentPath << " | dl: " << deadline << "\n";
								  break;
							  }
						  } else if (deadline < 0) {
							  if (sumDelay < abs(deadline)) {
								  needBlock = true;
								  cout << "block (reason: exceeDeadline [neg]) -> cp: " << currentPath << " | dl: " << deadline << "\n";
								  break;
							  }
						  }
						  // for checking capacity's satisfiability
						  sumCarry = sumCarry + pickDropArray[i][toColumn-2];
						  // cout << "busIdx: " << i << " | sc: " << sumCarry << " | +?/-?: " << pickDropArray[i][toColumn-2] << "\n";
						  if (sumCarry > capacityArray[i]) { // || sumCarry < 0) { // strange, but ...
							  needBlock = true;
							  reasonIsCapacity = true;
							  cout << "block (reason: exceedCapacity) -> cp: " << currentPath << " | sc: " << sumCarry << "\n";
							  break;
						  }
					  }
					  break;
				  }
				  if (chainsArray[i].size()-1 == acceptedSizeArray[i]) {
					  dummyBlock.clear();
					  for (int j=0; j<chainsArray[i].size(); j++) {
						  dummyBlock.push_back(chainsArray[i][j]);
					  }
					  needBlock = true;
					  break;
				  }
			  }
			  if (needBlock) {
				  // real add block clause here!
				  vec<Lit> block;
				  for (int i=0; i<dummyBlock.size(); i++) {
					  block.push(mkLit(dummyBlock[i]-1, (S.model[dummyBlock[i]-1]==l_True)?true:false));
				  }
				  S.addClause_(block);
				  answer = firstAns;
				  // for (int i=0; i<assumps.size(); i++) dummy.push(~assumps[i]);
				  // continue;
			  }
		  }
		  if (answerNew < currentMinAns && !needBlock) {
			  currentMinAns = answerNew;
			  if (card == 10 || card == 11 || card == 12){
				  lessthanMR(card, linkingVarMR,linkingWeightMR, answer,currentMinAns,ndivisor, cc, S, lits); //, assumps);
				  //for (int i=currentMinAns-1; i<assumps.size(); i++) dummy.push(assumps[i]);
				  //for (int i=0; i<currentMinAns-1; i++) dummy.push(~assumps[i]);
			  } else{
				  if (card == 1 && lcnt == 1)
					  answer = linkingVar.size();
				  lessthan(card, linkingVar,linkingWeight, answer,currentMinAns,divisor, cc, S, lits); //, assumps);
				  //for (int i=currentMinAns-1; i<assumps.size(); i++) dummy.push(assumps[i]);
				  //for (int i=0; i<currentMinAns-1; i++) dummy.push(~assumps[i]);
			  }
		  }
		  if (!needBlock) {
			  printf("cr ans = %d | currentMinAns = %d\n", answer, currentMinAns);
			  AnsChainsArray.clear();
			  for (int i=0; i<chainsArray.size(); i++) AnsChainsArray.push_back(chainsArray[i]);
		  }
		  answer = currentMinAns;
	  } else {
	    answer = answerNew;
	    ret = l_False; // koshi 20140124
	    break;
	  }
	} // end of while

	// Anonymous1 20181220 20190104 koshi 20140124
	if (ret == l_False) {
	  if (lcnt>0 && currentMinAns < firstAns) cout << "s OPTIMUM FOUND\n";
	  else if (needBlock && !reasonIsCapacity) cout << "s UNSATISFIABLE (reason: exceeDeadline)\n";
	  else if (needBlock && reasonIsCapacity) cout << "s UNSATISFIABLE (reason: exceedCapacity)\n";
	  else cout << "s UNSATISFIABLE\n";
	  // printf((lcnt > 0) ? "s OPTIMUM FOUND\n" : "s UNSATISFIABLE\n");
	} else {
	  printf("s UNKNOWN\n");
	  printf("c Search is stopped by a limit (maybe time-limit)\n");
	}
	if (lcnt > 0 ) {
	  if (pmodel == 1) {
	    printf("v ");
	    for (int i = 0; i< nbvar; i++) {
	      printf("%s%d ", mmodel[i]?"":"-", i+1);
	      if ((i+1)%20 == 0 && i+1 < nbvar) printf("\nv ");
	    }
	    printf("\n");
	  }
	}
	// Anonymous1 20181220 20190104
	const char *outFile = argv[3];
	ofstream ofs(outFile);
	if (lcnt>0 && currentMinAns < firstAns) {
		printf("final chain: [ | ");
		for (int i=0; i<AnsChainsArray.size(); i++) {
			for (int j=0; j<AnsChainsArray[i].size(); j++) printf("%d ", AnsChainsArray[i][j]);
			printf("| ");
		}
		printf("]\n");

		printf("cumulat. delay time: [ | ");
		int sumDelay;
		int weightIdxPlus = 0;
		for (int i=0; i<chainsArray.size(); i++) {
			sumDelay = 0;
			weightIdxPlus = (i==0)?0:(weightIdxPlus+(acceptedSizeArray[i-1]+2*newDemandSize)*(acceptedSizeArray[i-1]+2*newDemandSize+1));
			for (int j=0; j<chainsArray[i].size(); j++) {
				sumDelay = sumDelay + weights[chainsArray[i][j]-gridStartIndex[i]+weightIdxPlus];
				printf("%d ", sumDelay);
			}
			printf("| ");
		}
		printf("]\n");

		printf("cumulat. carried no.: [ | ");
		int sumCarry;
		for (int i=0; i<chainsArray.size(); i++) {
			sumCarry = nofCarried[i];
			for (int j=0; j<chainsArray[i].size(); j++) {
				int toColumn = fromTo(chainsArray[i][j], acceptedSizeArray[i]+2*newDemandSize, gridStartIndex[i]-1)-(gridStartIndex[i]-1);
				sumCarry = sumCarry + pickDropArray[i][toColumn-2];
				printf("%d ", sumCarry);
			}
			printf("| ");
		}
		printf("]\n");

		/*
		printf("cumulat. delay time: [ | ");
		int sumDelay;
		int weightIdxPlus = 0;
		for (int i=0; i<AnsChainsArray.size(); i++) {
			sumDelay = 0;
			weightIdxPlus = (i==0)?0:(weightIdxPlus+(acceptedSizeArray[i-1]+2*newDemandSize)*(acceptedSizeArray[i-1]+2*newDemandSize+1));
			for (int j=0; j<AnsChainsArray[i].size(); j++) {
				sumDelay = sumDelay + weights[AnsChainsArray[i][j]-gridStartIndex[i]+weightIdxPlus];
				if (AnsChainsArray[i].size() > acceptedSizeArray[i]) printf("%d ", sumDelay);
				else printf("- ");
			}
			printf("| ");
		}
		printf("]\n");
		

		printf("cumulat. carried no.: [ | ");
		int sumCarry;
		for (int i=0; i<AnsChainsArray.size(); i++) {
			sumCarry = nofCarried[i];
			for (int j=0; j<AnsChainsArray[i].size(); j++) {
				int toColumn = fromTo(AnsChainsArray[i][j], acceptedSizeArray[i]+2*newDemandSize, gridStartIndex[i]-1)-(gridStartIndex[i]-1);
				sumCarry = sumCarry + pickDropArray[i][toColumn-2];
				if (AnsChainsArray[i].size() > acceptedSizeArray[i]) printf("%d ", sumCarry);
				else printf("- ");
			}
			printf("| ");
		}
		printf("]\n");
		*/

		if (AnsChainsArray.size() > 0) {
			ofs << "OPT\n";
			for (int i=0; i<AnsChainsArray.size(); i++) {
				if (AnsChainsArray[i].size() > acceptedSizeArray[i]) ofs << i+1 << "\n";
				printf("semantic route (bus %d): ", i+1);
				for (int j=0; j<AnsChainsArray[i].size(); j++) {
					int locationID = (AnsChainsArray[i][j]-(gridStartIndex[i]-1))%(acceptedSizeArray[i]+2*newDemandSize+1);
					if (locationID == 0) locationID = acceptedSizeArray[i]+2*newDemandSize+1;
					if (j == AnsChainsArray[i].size()-1) {
						if (AnsChainsArray[i].size() > acceptedSizeArray[i]) printf("%d > %d", locationID, fromTo(AnsChainsArray[i][j], acceptedSizeArray[i]+2*newDemandSize, gridStartIndex[i]-1)-(gridStartIndex[i]-1));
						else printf("- > -");
						if (AnsChainsArray[i].size() > acceptedSizeArray[i]) ofs << locationID << " " << fromTo(AnsChainsArray[i][j], acceptedSizeArray[i]+2*newDemandSize, gridStartIndex[i]-1)-(gridStartIndex[i]-1);
					} else {
						if (AnsChainsArray[i].size() > acceptedSizeArray[i]) printf("%d > ", locationID);
						else printf("- > ");
						if (AnsChainsArray[i].size() > acceptedSizeArray[i]) ofs << locationID << " ";
					}
				}
				printf("\n");
				if (AnsChainsArray[i].size() > acceptedSizeArray[i]) ofs << "\n";
			}
		} else {
			ofs << "UNSAT\n";
			ofs << "time-limit\n";
		}
	} else if (needBlock && !reasonIsCapacity) {
		ofs << "UNSAT\n";
		ofs << "exceeDeadline\n";
	} else if (needBlock && reasonIsCapacity) {
		ofs << "UNSAT\n";
		ofs << "exceedCapacity\n";
	} else {
		ofs << "UNSAT\n";
		ofs << "unKnownReason\n";
	}

	if (lcnt > 0)
	  printf("c Latest Answer = %lld by %d loops\n",answer,lcnt);

	printStats(S);

	/* koshi 20140107
        if (S.verbosity > 0){
            printStats(S);
            printf("\n"); }

        printf(ret == l_True ? "SATISFIABLE\n" : ret == l_False ? "UNSATISFIABLE\n" : "INDETERMINATE\n");
        if (res != NULL){
            if (ret == l_True){
                fprintf(res, "SAT\n");
                for (int i = 0; i < S.nVars(); i++)
                    if (S.model[i] != l_Undef)
                        fprintf(res, "%s%s%d", (i==0)?"":" ", (S.model[i]==l_True)?"":"-", i+1);
                fprintf(res, " 0\n");
            }else if (ret == l_False)
                fprintf(res, "UNSAT\n");
            else
                fprintf(res, "INDET\n");
            fclose(res);
	*/

#ifdef NDEBUG
        exit(ret == l_True ? 10 : ret == l_False ? 20 : 0);     // (faster than "return", which will invoke the destructor for 'Solver')
#else
        return (ret == l_True ? 10 : ret == l_False ? 20 : 0);
#endif
    } catch (OutOfMemoryException&){
        printf("===============================================================================\n");
        printf("INDETERMINATE\n");
        exit(0);
    }
}
