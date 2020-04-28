#!/usr/bin/python
# -*- coding: UTF-8 -*-

from pysat.examples.rc2 import RC2
from pysat.formula import WCNF

#
#==============================================================================
class RTSS:
    nOfTaxi = 0
    newDemandSize = 0
    capacityOfEachTaxi = []
    noListOfPickDrop = [] # sorted (pair adjoining) future via points list of each taxi
    noListOfCarried = []
    noListOfAcceptedPoint = []
    currenTime = 10
    deadlineList = [] # assume that all pick-up points have no deadline request
    deadlineOfNewDemand = []
    cosTimeMatrices = [] # note that, the given symmetric cost time matrices have NOT been verified for any Euclidean axioms (such as triangle inequality)
    varID = 0
    maxWidthOfNet = 0
    conNet = []
    rchNet = []
    wcnf = None
    learntClause = [] # use for debug

    def __init__(self):
	self.nOfTaxi = 3
	self.newDemandSize = 2
	self.capacityOfEachTaxi = [3, 3, 3]
	self.noListOfPickDrop = [[1, -1], [1, -1, -2], [-3]]
	for i in range(len(self.noListOfPickDrop)):
		self.noListOfCarried.append(-1 * sum(self.noListOfPickDrop[i]))
	for i in range(len(self.noListOfPickDrop)):
		self.noListOfAcceptedPoint.append(len(self.noListOfPickDrop[i]))
	self.currenTime = 10
	self.deadlineList = [[self.currenTime, 40], [self.currenTime, 30, 60], [20]]
	self.deadlineOfNewDemand = [self.currenTime, 90]
	self.cosTimeMatrices = [[[0, 13, 54, 21, 46], 
			[13, 0, 29, 18, 64], 
			[54, 29, 0, 37, 25], 
			[21, 18, 37, 0, 34], 
			[46, 64, 25, 34, 0]], 

			[[0, 11, 38, 62, 19, 57], 
			[11, 0, 27, 45, 36, 49], 
			[38, 27, 0, 48, 65, 40], 
			[62, 45, 48, 0, 21, 31], 
			[19, 36, 65, 21, 0, 34], 
			[57, 49, 40, 31, 34, 0]], 

			[[0, 8, 28, 69], 
			[8, 0, 31, 52], 
			[28, 31, 0, 34], 
			[69, 52, 34, 0]]]
	self.maxWidthOfNet = 3 + max(self.noListOfAcceptedPoint)
	self.conNet = [[[0] * self.maxWidthOfNet for i in range(self.maxWidthOfNet)] for j in range(self.nOfTaxi)]
	self.rchNet = [[[0] * self.maxWidthOfNet for i in range(self.maxWidthOfNet)] for j in range(self.nOfTaxi)]
	self.wcnf = WCNF()

    def newVarID(self):
	self.varID += 1
	return self.varID

    def isRequiredVar(self, k, row, column):
	if row == 0 or row == column:
		return False
	elif row == 1+self.noListOfAcceptedPoint[k] and column == 1+row:
		return False
	elif row > 0 and row < self.noListOfAcceptedPoint[k] and self.noListOfPickDrop[k][row-1] > 0 and column == 1+row:
		return False
	else:
		return True

    def genVarForConNet(self):
	for k in range(self.nOfTaxi):
		for i in range(3+self.noListOfAcceptedPoint[k]):
			for j in range(3+self.noListOfAcceptedPoint[k]):
				if self.isRequiredVar(k, i, j):
					self.conNet[k][i][j] = self.newVarID()

    def genVarForRchNet(self):
	for k in range(self.nOfTaxi):
		for i in range(1+self.noListOfAcceptedPoint[k]):
			for j in range(1+i, 3+self.noListOfAcceptedPoint[k]):
				if self.isRequiredVar(k, i, j):
					self.rchNet[k][i][j] = self.newVarID()
		for j in range(1, self.noListOfAcceptedPoint[k]):
			for i in range(1+j, 1+self.noListOfAcceptedPoint[k]):
				if self.isRequiredVar(k, j, i):
					self.rchNet[k][i][j] = -1 * self.rchNet[k][j][i]
				else:
					self.rchNet[k][i][j] = self.newVarID()
		for i in range(1+self.noListOfAcceptedPoint[k], 3+self.noListOfAcceptedPoint[k]):
			for j in range(3+self.noListOfAcceptedPoint[k]):
				if self.isRequiredVar(k, i, j):
					self.rchNet[k][i][j] = self.newVarID()

    def netPrinter(self, net): # function for debug
	for k in range(self.nOfTaxi):
		for i in range(3+self.noListOfAcceptedPoint[k]):
			print(net[k][i][0:3+self.noListOfAcceptedPoint[k]])
		print('\n')

    def genSoftClause(self):
	for k in range(self.nOfTaxi):
		for i in range(3+self.noListOfAcceptedPoint[k]):
			for j in range(3+self.noListOfAcceptedPoint[k]):
				if self.isRequiredVar(k, i, j):
					self.wcnf.append([(-1 * self.rchNet[k][2+self.noListOfAcceptedPoint[k]][0]), (-1 * self.conNet[k][i][j])], weight = self.cosTimeMatrices[k][i][j])

    def genHardClauseForImplicationRule(self):
	for k in range(self.nOfTaxi):
		for i in range(3+self.noListOfAcceptedPoint[k]):
			for j in range(3+self.noListOfAcceptedPoint[k]):
				if self.isRequiredVar(k, i, j) and (i > self.noListOfAcceptedPoint[k] or j != 0):
					self.wcnf.append([(-1 * self.conNet[k][i][j]), self.rchNet[k][i][j]])

    def isTautologyVar(self, k, row, column):
	if column == 0 and row >= 1 and row <= self.noListOfAcceptedPoint[k]:
		return True
	else:
		return False

    def instinctLiteral(self, net, k, row, column, sign, isConNet):
	if sign and self.isRequiredVar(k, row, column):
		return net[k][row][column]
	elif isConNet and (not sign):
		return (-1 * net[k][row][column])
	elif (not isConNet) and (not sign) and (not self.isTautologyVar(k, row, column)):
		return (-1 * net[k][row][column])
	else:
		return 0

    def genHardClauseForChainTransitionLaw(self):
	for k in range(self.nOfTaxi):
		for a in range(1+self.noListOfAcceptedPoint[k]):
			for b in range(1+a, 2+self.noListOfAcceptedPoint[k]):
				for c in range(1+b, 3+self.noListOfAcceptedPoint[k]):
					# correspond to ¬rchNet[k][b][a] ∨ ¬rchNet[k][c][b] ∨ rchNet[k][c][a]
					if self.isRequiredVar(k, b, a) and self.isRequiredVar(k, c, b) and (not self.isTautologyVar(k, c, a)):
						literaList = [self.instinctLiteral(self.rchNet, k, b, a, False, False), 
								self.instinctLiteral(self.rchNet, k, c, b, False, False), 
								self.instinctLiteral(self.rchNet, k, c, a, True, False)]
						self.wcnf.append(filter(lambda elm: elm != 0, literaList))
						#print(filter(lambda elm: elm != 0, literaList))
					# correspond to ¬rchNet[k][b][a] ∨ ¬rchNet[k][c][b] ∨ ¬conNet[k][c][a]
					if self.isRequiredVar(k, b, a) and self.isRequiredVar(k, c, b) and self.isRequiredVar(k, c, a):
						literaList = [self.instinctLiteral(self.rchNet, k, b, a, False, False), 
								self.instinctLiteral(self.rchNet, k, c, b, False, False), 
								self.instinctLiteral(self.conNet, k, c, a, False, True)]
						self.wcnf.append(filter(lambda elm: elm != 0, literaList))
						#print(filter(lambda elm: elm != 0, literaList))
					# correspond to ¬rchNet[k][b][c] ∨ ¬rchNet[k][a][b] ∨ rchNet[k][a][c]
					if self.isRequiredVar(k, b, c) and self.isRequiredVar(k, a, b) and (not self.isTautologyVar(k, a, c)):
						literaList = [self.instinctLiteral(self.rchNet, k, b, c, False, False), 
								self.instinctLiteral(self.rchNet, k, a, b, False, False), 
								self.instinctLiteral(self.rchNet, k, a, c, True, False)]
						self.wcnf.append(filter(lambda elm: elm != 0, literaList))
						#print(filter(lambda elm: elm != 0, literaList))
					# correspond to ¬rchNet[k][b][c] ∨ ¬rchNet[k][a][b] ∨ ¬conNet[k][a][c]
					if self.isRequiredVar(k, b, c) and self.isRequiredVar(k, a, b) and self.isRequiredVar(k, a, c):
						literaList = [self.instinctLiteral(self.rchNet, k, b, c, False, False), 
								self.instinctLiteral(self.rchNet, k, a, b, False, False), 
								self.instinctLiteral(self.conNet, k, a, c, False, True)]
						self.wcnf.append(filter(lambda elm: elm != 0, literaList))
						#print(filter(lambda elm: elm != 0, literaList))

					# correspond to ¬rchNet[k][c][a] ∨ ¬rchNet[k][b][c] ∨ rchNet[k][b][a]
					if self.isRequiredVar(k, c, a) and self.isRequiredVar(k, b, c) and (not self.isTautologyVar(k, b, a)):
						literaList = [self.instinctLiteral(self.rchNet, k, c, a, False, False), 
								self.instinctLiteral(self.rchNet, k, b, c, False, False), 
								self.instinctLiteral(self.rchNet, k, b, a, True, False)]
						self.wcnf.append(filter(lambda elm: elm != 0, literaList))
						#print(filter(lambda elm: elm != 0, literaList))
					# correspond to ¬rchNet[k][c][a] ∨ ¬rchNet[k][b][c] ∨ ¬conNet[k][b][a]
					if self.isRequiredVar(k, c, a) and self.isRequiredVar(k, b, c) and self.isRequiredVar(k, b, a):
						literaList = [self.instinctLiteral(self.rchNet, k, c, a, False, False), 
								self.instinctLiteral(self.rchNet, k, b, c, False, False), 
								self.instinctLiteral(self.conNet, k, b, a, False, True)]
						self.wcnf.append(filter(lambda elm: elm != 0, literaList))
						#print(filter(lambda elm: elm != 0, literaList))
					# correspond to ¬rchNet[k][c][b] ∨ ¬rchNet[k][a][c] ∨ rchNet[k][a][b]
					if self.isRequiredVar(k, c, b) and self.isRequiredVar(k, a, c) and (not self.isTautologyVar(k, a, b)):
						literaList = [self.instinctLiteral(self.rchNet, k, c, b, False, False), 
								self.instinctLiteral(self.rchNet, k, a, c, False, False), 
								self.instinctLiteral(self.rchNet, k, a, b, True, False)]
						self.wcnf.append(filter(lambda elm: elm != 0, literaList))
						#print(filter(lambda elm: elm != 0, literaList))
					# correspond to ¬rchNet[k][c][b] ∨ ¬rchNet[k][a][c] ∨ ¬conNet[k][a][b]
					if self.isRequiredVar(k, c, b) and self.isRequiredVar(k, a, c) and self.isRequiredVar(k, a, b):
						literaList = [self.instinctLiteral(self.rchNet, k, c, b, False, False), 
								self.instinctLiteral(self.rchNet, k, a, c, False, False), 
								self.instinctLiteral(self.conNet, k, a, b, False, True)]
						self.wcnf.append(filter(lambda elm: elm != 0, literaList))
						#print(filter(lambda elm: elm != 0, literaList))

					if not (a >= 1 and c <= self.noListOfAcceptedPoint[k]):
						# correspond to ¬rchNet[k][a][b] ∨ ¬rchNet[k][c][a] ∨ rchNet[k][c][b]
						if self.isRequiredVar(k, a, b) and self.isRequiredVar(k, c, a) and (not self.isTautologyVar(k, c, b)):
							literaList = [self.instinctLiteral(self.rchNet, k, a, b, False, False), 
									self.instinctLiteral(self.rchNet, k, c, a, False, False), 
									self.instinctLiteral(self.rchNet, k, c, b, True, False)]
							self.wcnf.append(filter(lambda elm: elm != 0, literaList))
							#print(filter(lambda elm: elm != 0, literaList))
						# correspond to ¬rchNet[k][a][c] ∨ ¬rchNet[k][b][a] ∨ rchNet[k][b][c]
						if self.isRequiredVar(k, a, c) and self.isRequiredVar(k, b, a) and (not self.isTautologyVar(k, b, c)):
							literaList = [self.instinctLiteral(self.rchNet, k, a, c, False, False), 
									self.instinctLiteral(self.rchNet, k, b, a, False, False), 
									self.instinctLiteral(self.rchNet, k, b, c, True, False)]
							self.wcnf.append(filter(lambda elm: elm != 0, literaList))
							#print(filter(lambda elm: elm != 0, literaList))

					# correspond to ¬rchNet[k][a][b] ∨ ¬rchNet[k][c][a] ∨ ¬conNet[k][c][b]
					if self.isRequiredVar(k, a, b) and self.isRequiredVar(k, c, a) and self.isRequiredVar(k, c, b):
						literaList = [self.instinctLiteral(self.rchNet, k, a, b, False, False), 
								self.instinctLiteral(self.rchNet, k, c, a, False, False), 
								self.instinctLiteral(self.conNet, k, c, b, False, True)]
						self.wcnf.append(filter(lambda elm: elm != 0, literaList))
						#print(filter(lambda elm: elm != 0, literaList))
					# correspond to ¬rchNet[k][a][c] ∨ ¬rchNet[k][b][a] ∨ ¬conNet[k][b][c]
					if self.isRequiredVar(k, a, c) and self.isRequiredVar(k, b, a) and self.isRequiredVar(k, b, c):
						literaList = [self.instinctLiteral(self.rchNet, k, a, c, False, False), 
								self.instinctLiteral(self.rchNet, k, b, a, False, False), 
								self.instinctLiteral(self.conNet, k, b, c, False, True)]
						self.wcnf.append(filter(lambda elm: elm != 0, literaList))
						#print(filter(lambda elm: elm != 0, literaList))

    def genHardClauseForConfluenceLaw(self):
	for k in range(self.nOfTaxi):
		for a in range(1+self.noListOfAcceptedPoint[k]):
			for b in range(1+a, 2+self.noListOfAcceptedPoint[k]):
				for c in range(1+b, 3+self.noListOfAcceptedPoint[k]):
					# correspond to ¬rchNet[k][a][b] ∨ ¬rchNet[k][a][c] ∨ rchNet[k][c][b] ∨ rchNet[k][b][c]
					if (not c <= self.noListOfAcceptedPoint[k]) and self.isRequiredVar(k, a, b) and self.isRequiredVar(k, a, c) and (not self.isTautologyVar(k, c, b)) and (not self.isTautologyVar(k, b, c)):
						literaList = [self.instinctLiteral(self.rchNet, k, a, b, False, False), 
								self.instinctLiteral(self.rchNet, k, a, c, False, False), 
								self.instinctLiteral(self.rchNet, k, c, b, True, False),
								self.instinctLiteral(self.rchNet, k, b, c, True, False)]
						self.wcnf.append(filter(lambda elm: elm != 0, literaList))
						#print(filter(lambda elm: elm != 0, literaList))
					# correspond to ¬rchNet[k][b][a] ∨ ¬rchNet[k][b][c] ∨ rchNet[k][c][a] ∨ rchNet[k][a][c]
					if (not (a >=1 and c <= self.noListOfAcceptedPoint[k])) and self.isRequiredVar(k, b, a) and self.isRequiredVar(k, b, c) and (not self.isTautologyVar(k, c, a)) and (not self.isTautologyVar(k, a, c)):
						literaList = [self.instinctLiteral(self.rchNet, k, b, a, False, False), 
								self.instinctLiteral(self.rchNet, k, b, c, False, False), 
								self.instinctLiteral(self.rchNet, k, c, a, True, False),
								self.instinctLiteral(self.rchNet, k, a, c, True, False)]
						self.wcnf.append(filter(lambda elm: elm != 0, literaList))
						#print(filter(lambda elm: elm != 0, literaList))
					# correspond to ¬rchNet[k][c][a] ∨ ¬rchNet[k][c][b] ∨ rchNet[k][b][a] ∨ rchNet[k][a][b]
					if (not (a >=1 and b <= self.noListOfAcceptedPoint[k])) and self.isRequiredVar(k, c, a) and self.isRequiredVar(k, c, b) and (not self.isTautologyVar(k, b, a)) and (not self.isTautologyVar(k, a, b)):
						literaList = [self.instinctLiteral(self.rchNet, k, c, a, False, False), 
								self.instinctLiteral(self.rchNet, k, c, b, False, False), 
								self.instinctLiteral(self.rchNet, k, b, a, True, False),
								self.instinctLiteral(self.rchNet, k, a, b, True, False)]
						self.wcnf.append(filter(lambda elm: elm != 0, literaList))
						#print(filter(lambda elm: elm != 0, literaList))

    def genHardClauseForRamificationLaw(self):
	for k in range(self.nOfTaxi):
		for a in range(1+self.noListOfAcceptedPoint[k]):
			for b in range(1+a, 2+self.noListOfAcceptedPoint[k]):
				for c in range(1+b, 3+self.noListOfAcceptedPoint[k]):
					# correspond to ¬rchNet[k][b][a] ∨ ¬rchNet[k][c][a] ∨ rchNet[k][c][b] ∨ rchNet[k][b][c]
					if (not c <= self.noListOfAcceptedPoint[k]) and self.isRequiredVar(k, b, a) and self.isRequiredVar(k, c, a) and (not self.isTautologyVar(k, c, b)) and (not self.isTautologyVar(k, b, c)):
						literaList = [self.instinctLiteral(self.rchNet, k, b, a, False, False), 
								self.instinctLiteral(self.rchNet, k, c, a, False, False), 
								self.instinctLiteral(self.rchNet, k, c, b, True, False),
								self.instinctLiteral(self.rchNet, k, b, c, True, False)]
						self.wcnf.append(filter(lambda elm: elm != 0, literaList))
						#print(filter(lambda elm: elm != 0, literaList))
					# correspond to ¬rchNet[k][a][b] ∨ ¬rchNet[k][c][b] ∨ rchNet[k][c][a] ∨ rchNet[k][a][c]
					if (not (a >=1 and c <= self.noListOfAcceptedPoint[k])) and self.isRequiredVar(k, a, b) and self.isRequiredVar(k, c, b) and (not self.isTautologyVar(k, c, a)) and (not self.isTautologyVar(k, a, c)):
						literaList = [self.instinctLiteral(self.rchNet, k, a, b, False, False), 
								self.instinctLiteral(self.rchNet, k, c, b, False, False), 
								self.instinctLiteral(self.rchNet, k, c, a, True, False),
								self.instinctLiteral(self.rchNet, k, a, c, True, False)]
						self.wcnf.append(filter(lambda elm: elm != 0, literaList))
						#print(filter(lambda elm: elm != 0, literaList))
					# correspond to ¬rchNet[k][a][c] ∨ ¬rchNet[k][b][c] ∨ rchNet[k][b][a] ∨ rchNet[k][a][b]
					if (not (a >=1 and b <= self.noListOfAcceptedPoint[k])) and self.isRequiredVar(k, a, c) and self.isRequiredVar(k, b, c) and (not self.isTautologyVar(k, b, a)) and (not self.isTautologyVar(k, a, b)):
						literaList = [self.instinctLiteral(self.rchNet, k, a, c, False, False), 
								self.instinctLiteral(self.rchNet, k, b, c, False, False), 
								self.instinctLiteral(self.rchNet, k, b, a, True, False),
								self.instinctLiteral(self.rchNet, k, a, b, True, False)]
						self.wcnf.append(filter(lambda elm: elm != 0, literaList))
						#print(filter(lambda elm: elm != 0, literaList))

    def genHardClauseForAcyclicLaw(self):
	for k in range(self.nOfTaxi):
		for a in range(2+self.noListOfAcceptedPoint[k]):
			for b in range(1+a, 3+self.noListOfAcceptedPoint[k]):
				# correspond to ¬rchNet[k][b][a] ∨ ¬rchNet[k][a][b]
				if (not (a >=1 and b <= self.noListOfAcceptedPoint[k])) and self.isRequiredVar(k, b, a) and self.isRequiredVar(k, a, b):
					self.wcnf.append([(-1 * self.rchNet[k][b][a]), (-1 * self.rchNet[k][a][b])])

    def atLeastOne(self, varList):
	self.wcnf.append(varList)

    def genHardClauseForEq6(self):
	for k in range(self.nOfTaxi):
		for i in range(1, 1+self.noListOfAcceptedPoint[k]):
			varList = []
			for j in range(0, 3+self.noListOfAcceptedPoint[k]):
				if self.isRequiredVar(k, i, j):
					varList.append(self.conNet[k][i][j])
			self.atLeastOne(varList)

    def genHardClauseForEq7(self):
	for k in range(self.nOfTaxi):
		for i in range(1, 1+self.noListOfAcceptedPoint[k]):
			if self.noListOfPickDrop[k][i-1] > 0:
				varList = []
				for j in range(1, 3+self.noListOfAcceptedPoint[k]):
					if self.isRequiredVar(k, j, i):
						varList.append(self.conNet[k][j][i])
				self.atLeastOne(varList)

    def atMostOne(self, varList):
	for i in range(len(varList)):
		for j in range(1+i, len(varList)):
			self.wcnf.append([(-1 * varList[i]), (-1 * varList[j])])

    def exactlyOne(self, varList):
	self.atMostOne(varList)
	self.atLeastOne(varList)

    def genHardClauseForEq8(self):
	varList = []
	for k in range(self.nOfTaxi):
		for i in range(3+self.noListOfAcceptedPoint[k]):
			if self.isRequiredVar(k, 1+self.noListOfAcceptedPoint[k], i):
				varList.append(self.conNet[k][1+self.noListOfAcceptedPoint[k]][i])
	self.exactlyOne(varList)

    def genHardClauseForEq9(self):
	varList = []
	for k in range(self.nOfTaxi):
		for i in range(3+self.noListOfAcceptedPoint[k]):
			if self.isRequiredVar(k, 2+self.noListOfAcceptedPoint[k], i):
				varList.append(self.conNet[k][2+self.noListOfAcceptedPoint[k]][i])
	self.exactlyOne(varList)

    def genHardClauseForEq10(self):
	varList = []
	for k in range(self.nOfTaxi):
		for i in range(1, 3+self.noListOfAcceptedPoint[k]):
			if self.isRequiredVar(k, i, 1+self.noListOfAcceptedPoint[k]):
				varList.append(self.conNet[k][i][1+self.noListOfAcceptedPoint[k]])
	self.exactlyOne(varList)

    def genHardClauseForEq11(self):
	varList = []
	for k in range(self.nOfTaxi):
		for i in range(1, 3+self.noListOfAcceptedPoint[k]):
			if self.isRequiredVar(k, i, 2+self.noListOfAcceptedPoint[k]):
				varList.append(self.conNet[k][i][2+self.noListOfAcceptedPoint[k]])
	self.atMostOne(varList)

    def genHardClauseForEq12(self):
	for k in range(self.nOfTaxi):
		if self.noListOfAcceptedPoint[k] != 0:
			varList = []
			for i in range(1, 3+self.noListOfAcceptedPoint[k]):
				if self.isRequiredVar(k, i, 0):
					varList.append(self.conNet[k][i][0])
			self.atLeastOne(varList)

    def genHardClauseForEq16(self):
	for k in range(self.nOfTaxi):
		for i in range(1, 1+self.noListOfAcceptedPoint[k]):
			if self.noListOfPickDrop[k][i-1] > 0:
				self.wcnf.append([self.rchNet[k][i+1][i]])

    def genHardClauseForEqs17And18(self):
	for k in range(self.nOfTaxi):
		self.wcnf.append([(-1 * self.rchNet[k][1+self.noListOfAcceptedPoint[k]][0]), self.rchNet[k][2+self.noListOfAcceptedPoint[k]][1+self.noListOfAcceptedPoint[k]]])
		self.wcnf.append([(-1 * self.rchNet[k][2+self.noListOfAcceptedPoint[k]][0]), self.rchNet[k][2+self.noListOfAcceptedPoint[k]][1+self.noListOfAcceptedPoint[k]]])

    def genHardClauseForEq19(self):
	varList = []
	for k in range(self.nOfTaxi):
		varList.append(self.rchNet[k][2+self.noListOfAcceptedPoint[k]][1+self.noListOfAcceptedPoint[k]])
	self.atMostOne(varList)

    def getLastVarIDinConNet(self):
	k = self.nOfTaxi - 1
	row = 2 + self.noListOfAcceptedPoint[k]
	column = row - 1
	return self.conNet[k][row][column]

    def fromTo(self, k, column):
	listOfCandidateMove = []
	for row in range(1, 3+self.noListOfAcceptedPoint[k]):
		listOfCandidateMove.append(self.conNet[k][row][column])
	return listOfCandidateMove

    def decodeAllModels(self, model):
	listOfRoute = []
	for k in range(self.nOfTaxi):
		listOFromTo = [0]
		listOfCandidateMove = self.fromTo(k, 0)
		while len(listOfCandidateMove) != 0:
			for i in range(len(listOfCandidateMove)):
				if listOfCandidateMove[i] in model:
					listOFromTo.append(1+i)
					listOfCandidateMove = self.fromTo(k, 1+i)
					break
				elif i == len(listOfCandidateMove) - 1:
					listOfCandidateMove = []
		listOfRoute.append(listOFromTo)
	print(listOfRoute)
	return listOfRoute

    def decodeModel(self, model):
	for k in range(self.nOfTaxi):
		listOfCandidateMove = filter(lambda elm: elm != 0, self.conNet[k][1+self.noListOfAcceptedPoint[k]])
		for i in range(len(listOfCandidateMove)):
			if listOfCandidateMove[i] in model:
				return (k, self.decodeAllModels(model)[k])

    def checkExCondition(self, taxID, route):
	isViolate = False
	sumDelay = 0
	sumCarried = self.noListOfCarried[taxID]
	reasoNegation = []
	exNoListOfPickDrop = [0] + self.noListOfPickDrop[taxID] + [self.newDemandSize, -1 * self.newDemandSize]
	exDeadlineList = [self.currenTime] + self.deadlineList[taxID] + self.deadlineOfNewDemand
	for i in range(len(route)-1):
		reasoNegation.append(-1 * self.conNet[taxID][route[1+i]][route[i]])
		# checking for deadline contraints
		sumDelay += self.cosTimeMatrices[taxID][route[1+i]][route[i]]
		if exNoListOfPickDrop[route[1+i]] < 0:
			if sumDelay > (exDeadlineList[route[1+i]] - self.currenTime):
				isViolate = True
				break
		elif exNoListOfPickDrop[route[1+i]] > 0:
			if sumDelay < (exDeadlineList[route[1+i]] - self.currenTime):
				isViolate = True
				break
		# checking for capacity constraints
		sumCarried += exNoListOfPickDrop[route[1+i]]
		if sumCarried > self.capacityOfEachTaxi[taxID]:
			isViolate = True
			break
	return (isViolate, reasoNegation)

    def writExternalityFile(self):
	externalityFile = open('externality.txt', 'w')
	externalityFile.write('nOfTaxi %d' % self.nOfTaxi)
	externalityFile.write('\nnewDemandSize %d' % self.newDemandSize)
	externalityFile.write('\ncapacityOfEachTaxi')
	for i in range(len(self.capacityOfEachTaxi)):
		externalityFile.write(' %d' % self.capacityOfEachTaxi[i])
	externalityFile.write('\nnoListOfCarried')
	for i in range(len(self.noListOfCarried)):
		externalityFile.write(' %d' % self.noListOfCarried[i])
	externalityFile.write('\nnoListOfAcceptedPoint')
	for i in range(len(self.noListOfAcceptedPoint)):
		externalityFile.write(' %d' % self.noListOfAcceptedPoint[i])
	externalityFile.write('\nnoListOfPickDrop')
	for i in range(len(self.noListOfPickDrop)):
		for j in range(len(self.noListOfPickDrop[i])):
			externalityFile.write(' %d' % self.noListOfPickDrop[i][j])
	externalityFile.write('\ncurrenTime %d' % self.currenTime)
	externalityFile.write('\ndeadlineList')
	for i in range(len(self.deadlineList)):
		for j in range(len(self.deadlineList[i])):
			externalityFile.write(' %d' % self.deadlineList[i][j])
	externalityFile.write('\ndeadlineOfNewDemand %d %d' % (self.deadlineOfNewDemand[0], self.deadlineOfNewDemand[1]))
	externalityFile.close()

    def solveRTSS(self, rc2):
	unviolatedModel = None
	model = rc2.compute()
	while model != None:
		model = filter(lambda elm: (elm > 0 and elm <= self.getLastVarIDinConNet()), model)
		#print(model)
		taxID, route = self.decodeModel(model)
		print(taxID, route, rc2.cost)
		isViolate, reasoNegation = self.checkExCondition(taxID, route)
		#print('reNeg', reasoNegation)
		#print('violate', isViolate)
		if isViolate:
			rc2.add_clause(reasoNegation)
			self.learntClause.append(reasoNegation)
			model = rc2.compute()
		else:
			unviolatedModel = model
			break
	return unviolatedModel

#==============================================================================
#

#===========================
if __name__ == '__main__':
    rtss = RTSS()
    rtss.genVarForConNet()
    rtss.genVarForRchNet()
    # rtss.netPrinter(rtss.conNet)
    # rtss.netPrinter(rtss.rchNet)

    rtss.genSoftClause()
    rtss.genHardClauseForImplicationRule()
    rtss.genHardClauseForChainTransitionLaw()
    rtss.genHardClauseForConfluenceLaw()
    rtss.genHardClauseForRamificationLaw()
    rtss.genHardClauseForAcyclicLaw()
    rtss.genHardClauseForEq6()
    rtss.genHardClauseForEq7()
    rtss.genHardClauseForEq8()
    rtss.genHardClauseForEq9()
    rtss.genHardClauseForEq10()
    rtss.genHardClauseForEq11()
    rtss.genHardClauseForEq12()
    rtss.genHardClauseForEq16()
    rtss.genHardClauseForEqs17And18()
    rtss.genHardClauseForEq19()

    rtss.wcnf.to_file('rtss.wcnf') # output wcnf file
    rtss.writExternalityFile() # output externality file

'''
with RC2(rtss.wcnf, incr=True, verbose=2) as rc2:
    model = rtss.solveRTSS(rc2)
    if model != None:
	print(rtss.decodeModel(model))
	print('cost: {}'.format(rc2.cost))
    else:
	print('UNSAT')
    print('c oracle time: {0:.4f}'.format(rc2.oracle_time()))
'''







