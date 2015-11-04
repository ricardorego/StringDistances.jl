##############################################################################
##
## Define QGram Distance type
##
##############################################################################
abstract AbstractQGram <: SemiMetric

##############################################################################
##
## Define a type that iterates through q-grams of a string
##
##############################################################################

type QGramIterator{S <: AbstractString, T <: Integer}
	s::S # string
	l::Int # length of string
	q::T # length of q-grams
end
function Base.start(qgram::QGramIterator)
	len = length(qgram.s)
	(1, len < qgram.q ? endof(qgram.s) + 1 : chr2ind(qgram.s, qgram.q))
end
function Base.next(qgram::QGramIterator, state)
	istart, iend = state
	element = SubString(qgram.s, istart, iend)
	nextstate = nextind(qgram.s, istart), nextind(qgram.s, iend)
	return element, nextstate
end
function Base.done(qgram::QGramIterator, state)
	istart, idend = state
	done(qgram.s, idend)
end
Base.eltype(qgram::QGramIterator) = SubString{typeof(qgram.s)}
Base.length(qgram::QGramIterator) = max(qgram.l - qgram.q + 1, 0)
function Base.collect(qgram::QGramIterator)
	x = Array(eltype(qgram), length(qgram))
	i = 0
	for q in qgram
		i += 1
		@inbounds x[i] = q
	end
	return x
end
Base.sort(qgram::QGramIterator) = sort!(collect(qgram))

##############################################################################
##
## Define a type that iterates through a pair of sorted vector
## For each element in either v1 or v2, output number of times it appears in v1 and the number of times it appears in v2
##
##############################################################################

type PairIterator{T1 <: AbstractVector, T2 <: AbstractVector}
	v1::T1
	v2::T2
end
Base.start(s::PairIterator) = (1, 1)

function Base.next(s::PairIterator, state)
	state1, state2 = state
	iter1 = done(s.v2, state2)
	iter2 = done(s.v1, state1)
	if iter1
		@inbounds x1 = s.v1[state1]
	elseif iter2
		@inbounds x2 = s.v2[state2]
	else
		@inbounds x1 = s.v1[state1]
		@inbounds x2 = s.v2[state2]
		iter1 = x1 <= x2
		iter2 = x2 <= x1
	end
	nextstate1 = iter1 ? searchsortedlast(s.v1, x1, state1, length(s.v1), Base.Forward) + 1 : state1
	nextstate2 = iter2 ? searchsortedlast(s.v2, x2, state2, length(s.v2), Base.Forward) + 1 : state2
	return ((nextstate1 - state1, nextstate2 - state2), (nextstate1, nextstate2))
end

function Base.done(s::PairIterator, state) 
	state1, state2 = state
	done(s.v2, state2) && done(s.v1, state1)
end

function PairIterator(s1::AbstractString, s2::AbstractString, len1::Integer, len2::Integer, q::Integer)
	sort1 = sort(QGramIterator(s1, len1, q))
	sort2 = sort(QGramIterator(s2, len2, q))
	PairIterator(sort1, sort2)
end
##############################################################################
##
## q-gram 
## Define v(s) a vector on the space of q-uple which contains number of times it appears in s
## For instance v("leila")["il"] =1 
## q-gram is ∑ |v(s1, p) - v(s2, p)|
##
##############################################################################

immutable QGram{T <: Integer} <: AbstractQGram
	q::T
end
QGram() = QGram(2)

function evaluate(dist::QGram, s1::AbstractString, s2::AbstractString, len1::Integer, len2::Integer)
	n = 0
	for (n1, n2) in PairIterator(s1, s2, len1, len2, dist.q)
		n += abs(n1 - n2)
	end
	return n
end

function qgram(s1::AbstractString, s2::AbstractString; q::Integer = 2)
	evaluate(QGram(q), s1::AbstractString, s2::AbstractString)
end

##############################################################################
##
## cosine 
##
## 1 - v(s1, p).v(s2, p)  / ||v(s1, p)|| * ||v(s2, p)||
##############################################################################

immutable Cosine{T <: Integer} <: AbstractQGram
	q::T
end
Cosine() = Cosine(2)

function evaluate(dist::Cosine, s1::AbstractString, s2::AbstractString, len1::Integer, len2::Integer)
	len1 <= (dist.q - 1) && return convert(Float64, s1 != s2)
	norm1, norm2, prodnorm = 0, 0, 0
	for (n1, n2) in PairIterator(s1, s2, len1, len2, dist.q)
		norm1 += n1^2
		norm2 += n2^2
		prodnorm += n1 * n2
	end
	return 1.0 - prodnorm / (sqrt(norm1) * sqrt(norm2))
end

function cosine(s1::AbstractString, s2::AbstractString; q::Integer = 2)
	evaluate(Cosine(q), s1::AbstractString, s2::AbstractString)
end

##############################################################################
##
## Jaccard
##
## Denote Q(s, q) the set of tuple of length q in s
## 1 - |intersect(Q(s1, q), Q(s2, q))| / |union(Q(s1, q), Q(s2, q))|
##
##############################################################################

immutable Jaccard{T <: Integer} <: AbstractQGram
	q::T
end
Jaccard() = Jaccard(2)

function evaluate(dist::Jaccard, s1::AbstractString, s2::AbstractString, len1::Integer, len2::Integer)
	len1 <= (dist.q - 1) && return convert(Float64, s1 != s2)
	ndistinct1, ndistinct2, nintersect = 0, 0, 0
	for (n1, n2) in PairIterator(s1, s2, len1, len2, dist.q)
		ndistinct1 += n1 > 0
		ndistinct2 += n2 > 0
		nintersect += (n1 > 0) & (n2 > 0)
	end
	return 1.0 - nintersect / (ndistinct1 + ndistinct2 - nintersect)
end

function jaccard(s1::AbstractString, s2::AbstractString; q::Integer = 2)
	evaluate(Jaccard(q), s1::AbstractString, s2::AbstractString)
end