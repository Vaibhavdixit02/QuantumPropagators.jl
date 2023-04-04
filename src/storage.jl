module Storage

using LinearAlgebra

export init_storage, map_observables, map_observable, write_to_storage!
export get_from_storage!

"""Create a `storage` array for propagation.

```julia
storage = init_storage(state, tlist)
```

creates a storage array suitable for storing a `state` for each point in
`tlist`.

```julia
storage = init_storage(state, tlist, observables)
```

creates a storage array suitable for the data generated by the `observables`
applied to `state`, see [`map_observables`](@ref), for each point in `tlist`.

```julia
storage = init_storage(data, nt)
```

creates a storage arrays suitable for storing `data` nt times, where
`nt=length(tlist)`. By default, this will be a vector of `typeof(data)` and
length `nt`, or a `n × nt` Matrix with the same `eltype` as `data` if `data` is
a Vector of length `n`.
"""
function init_storage(state, tlist::AbstractVector)
    nt = length(tlist)
    return init_storage(state, nt)
end

function init_storage(state, tlist, observables)
    data = map_observables(observables, tlist, 1, state)
    # We're assuming type stability here: the `typeof(data)` must not depend
    # on the time index
    nt = length(tlist)
    return init_storage(data, nt)
end

init_storage(data::T, nt::Integer) where {T} = Vector{T}(undef, nt)

init_storage(data::Vector{T}, nt::Integer) where {T} = Matrix{T}(undef, length(data), nt)


"""Obtain "observable" data from `state`.

```julia
data = map_observables(observables, tlist, i, state)
```

calculates the data for a tuple of `observables` applied to `state` defined at
time `tlist[i]`. For a single observable (tuple of length 1), simply return the
result of [`map_observable`](@ref).

For multiple observables, return the tuple resulting from applying
[`map_observable`](@ref) for each observable. If the tuple is "uniform" (all
elements are of the same type, e.g. if each observable calculates the
expectation value of a Hermitian operator), it is converted to a Vector. This
allows for compact storage in a storage array, see [`init_storage`](@ref).
"""
function map_observables(observables, tlist, i, state)
    if length(observables) == 1
        return map_observable(observables[1], tlist, i, state)
    else
        val_tuple = Tuple(map_observable(O, tlist, i, state) for O in observables)
        uniform_type = typeof(val_tuple[1])
        is_uniform = all(typeof(v) == uniform_type for v in val_tuple[2:end])
        if is_uniform
            return collect(val_tuple)  # convert to Vector
        else
            return val_tuple
        end
    end
end


"""Apply a single `observable` to `state`.

```julia
data = map_observable(observable, tlist, i, state)
```

By default, `observable` can be one of the following:

* A function taking the three arguments `state`, `tlist`, `i`, where `state` is
  defined at time `tlist[i]`.
* A function taking a single argument `state`, under the assumption that the
  observable is time-independent
* A matrix for which to calculate the expectation value with respect to the
  vector `state`.

The default [`map_observables`](@ref) delegates to this function.
"""
function map_observable(
    observable::F,
    tlist::TT,
    i::IT,
    state::ST
) where {F<:Function,TT,IT,ST}
    # The runtime dispatch below on the number of positional argument has a
    # very small overhead. To avoid it entirely, define a new method
    # specifically for a specific function
    # (map_observable(observable::typeof(myfunc), ...)
    if length(methods(observable, (ST, TT, IT))) > 0
        return observable(state, tlist, i)
    elseif length(methods(observable, (ST,))) > 0
        return observable(state)
    else
        error(
            "The `observable` function $observable must take either the single argument `state`, or the three arguments `state`, `tlist`, and `i`."
        )
    end
end

function map_observable(observable::AbstractMatrix, tlist, i, state::AbstractVector)
    return dot(state, observable, state)
end


"""Place data into `storage` for time slot `i`.

```julia
write_to_storage!(storage, i, data)
```

for a `storage` array created by [`init_storage`](@ref) stores the `data`
obtained from [`map_observables`](@ref) at time slot `i`.

Conceptually, this corresponds roughly to `storage[i] = data`, but `storage`
may have its own idea on how to store data for a specific time slot. For
example, with the default [`init_storage`](@ref) Vector data will be stored in
a matrix, and `write_to_storage!` will in this case write data to the i'th
column of the matrix.

For a given type of `storage` and `data`, it is the developer's responsibility
that [`init_storage`](@ref) and `write_to_storage!` are compatible.
"""
function write_to_storage!(storage::AbstractVector, i::Integer, data)
    storage[i] = data
end

function write_to_storage!(storage::Matrix{T}, i::Integer, data::Vector{T}) where {T}
    storage[:, i] .= data
end


"""Obtain data from storage.

```julia
get_from_storage!(data, storage, i)
```

extracts data from the `storage` for the i'th time slot. Inverse of
[`write_to_storage!`](@ref). This modifies `data` in-place. If
`get_from_storage!` is implemented for arbitrary `observables`, it is the
developer's responsibility
that [`init_storage`](@ref),  [`write_to_storage!`](@ref), and
`get_from_storage!` are compatible.
"""
get_from_storage!(data, storage::AbstractVector, i) = copyto!(data, storage[i])
get_from_storage!(data, storage::Matrix, i) = copyto!(data, storage[:, i])

end
