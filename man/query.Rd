% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/query.R
\name{query_by}
\alias{query_by}
\alias{fullhistory}
\title{Query the current history.}
\usage{
query_by(..., .related = "plots")

fullhistory()
}
\arguments{
\item{...}{Search conditions.}

\item{.related}{Included related entities (objects or plots).}
}
\value{
`query_by` return a history graph reduced according to
conditions specified in the call.

`fullhistory` returns the full history graph.
}
\description{
`query_by` accepts an arbitrary list of expressions and
returns objects and plots for which all evaluate to `TRUE`.

`fullhistory` is an equivalent to calling `query_by`
without any conditions.
}
\details{
The following helper functions can be use in expressions
to define conditions:
* `is_named(...)` name matches any from the list
* `inherits` object inherits from any of the specified classes

The following variables can be used in expressions when defining
conditions:
* `name` object name
* `class` object class
* `id` object identifier`
}
\examples{
\dontrun{
# search for a specific class
query_by(inherits("lm", "data.frame"))
query_by(lm \%in\% class || "data.frame" \%in\% class)

# search for a specific name
query_by(is_named("input", "x", "model"))
query_by(name == "input" || name == "x" || name == "model")
}

}
