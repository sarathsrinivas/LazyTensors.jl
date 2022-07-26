module LazyTensors

using GPUArrays

export LazyTensor, BroadcastArray, unwrap, LazyTensorStyle, pev, ev, reduce, reduce!, sum!,
    prod!, tsum, tprod, tsum!, tprod!, treduce!, treduce, halve_dims, halve

struct LazyTensor{T,N,A<:AbstractArray{T,N}} <: DenseArray{T,N}
    dat::A
    LazyTensor(a::AbstractArray{T,N}) where {T,N} = new{T,N,typeof(a)}(a)
end

@inline LazyTensor(a) = a

Base.parent(a::LazyTensor) = a.dat

Base.size(a::LazyTensor) = size(a.dat)
Base.getindex(a::LazyTensor, i...) = LazyTensor(a.dat[i...])
function Base.getindex(a::LazyTensor,
    I::Vararg{Union{<:AbstractUnitRange,Colon,Vector{CartesianIndex{0}}}})
    return LazyTensor(view(a.dat, I...))
end
Base.setindex!(a::LazyTensor, value, i...) = setindex!(a.dat, value, i...)
Base.eachindex(a::LazyTensor) = eachindex(a.dat)
Base.strides(a::LazyTensor) = strides(a.dat)

struct LazyTensorStyle <: Base.Broadcast.BroadcastStyle end

Base.BroadcastStyle(::Type{<:LazyTensor}) = LazyTensorStyle()

Base.BroadcastStyle(::LazyTensorStyle, ::Broadcast.BroadcastStyle) = LazyTensorStyle()

Base.materialize(bc::Broadcast.Broadcasted{LazyTensorStyle}) = BroadcastArray(unwrap(bc))

function Base.eltype(bc::Broadcast.Broadcasted)
    bci = Broadcast.instantiate(bc)
    return Broadcast.combine_eltypes(bci.f, bci.args)
end

function unwrap(bc::Broadcast.Broadcasted{LazyTensorStyle})
    return Broadcast.instantiate(Broadcast.broadcasted(bc.f, map(unwrap, bc.args)...))
end

unwrap(x) = x
unwrap(a::LazyTensor) = a.dat

struct BroadcastArray{T,N,B<:Base.AbstractBroadcasted} <: AbstractArray{T,N}
    bc::B
end

function BroadcastArray(bc::Broadcast.Broadcasted)
    T = eltype(bc)
    N = length(size(bc))
    return BroadcastArray{T,N,typeof(bc)}(bc)
end

function BroadcastArray(g::Base.Generator)
    bc = Broadcast.instantiate(Broadcast.broadcasted(g.f, g.iter))
    return BroadcastArray(bc)
end

Base.getindex(b::BroadcastArray, i...) = b.bc[i...]
function Base.getindex(a::BroadcastArray,
    I::Vararg{Union{<:AbstractUnitRange,Colon,Vector{CartesianIndex{0}}}})
    return view(a, I...)
end
Base.size(b::BroadcastArray) = size(b.bc)
Base.parent(b::BroadcastArray) = b.bc
Base.eachindex(b::BroadcastArray) = eachindex(b.bc)

Base.BroadcastStyle(::Type{<:BroadcastArray}) = LazyTensorStyle()

unwrap(a::BroadcastArray) = a.bc

function Base.show(io::IO, ::MIME"text/plain", ba::BroadcastArray)
    println("$(size(ba)) BroadcastArray{$(eltype(ba)), $(ndims(ba))}")
    println(" ")
    println(size.(ba.bc.args))
end

include("collect.jl")
include("reduce.jl")
include("reducedim.jl")
include("treduce.jl")
include("treducedim.jl")
include("GPU.jl")

end