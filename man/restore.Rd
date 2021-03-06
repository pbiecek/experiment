% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/track.R
\name{restore}
\alias{restore}
\title{Restore a snapshot from history.}
\usage{
restore(id)
}
\arguments{
\item{id}{`commit` or object identifier, a SHA1 string (__long id__)
or its first 8 characters (__short id__).}
}
\description{
Restores a historical [commit] from commit or object `id`:
* commit `id` brings back that specific commit
* object `id` brings back the earlies commit where that
  object can be found, which should be the commit where that
  object has been created
}
