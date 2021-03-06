#' Graph of all commits in `store`.
#'
#' Reads all commits from `store` and assigns the `children` and
#' `level` attributes. `children` is a `character` vector containing
#' identifiers of children commit, `level` is the distance from the
#' root of the tree.
#'
#' @param store A data store, e.g. `storage::filesystem`.
#' @param .data Wether to read full object data.
#' @return An object of S3 class `graph`.
#'
#' @import storage
#' @rdname graph
#'
graph <- function (store, .data = FALSE)
{
  # read all commits
  ids <- storage::os_find(store, lazyeval::lazy_dots(class == 'commit'))

  commits <- lapply(ids, function (commit_id)
    commit_restore(commit_id, store, .data = .data))

  if (!length(commits)) {
    stop("history is empty", call. = FALSE)
  }

  names(commits) <- ids

  commits <- structure(commits, class = 'graph')
  assign_children(commits, find_root_id(commits), 1)
}

# identify children and levels; start with root
# used only inside graph()
assign_children <- function (commits, id, level)
{
  found <- names(Filter(function (co) co$parent == id, commits))
  commits[[id]]$children <- found
  commits[[id]]$level <- level

  for (id in found) {
    commits <- assign_children(commits, id, level + 1)
  }

  commits
}


#' @rdname graph
is_graph <- function (x) inherits(x, 'graph')


#' @rdname graph
#' @export
#' @import htmlwidgets
#'
#' @examples
#' plot(graph(modelling()))
#'
plot.graph <- function (x, ...)
{
  plot(graph_to_steps(x))
}


#' Transform a graph of commits into a graph of steps.
#'
#' A step is an introduction of a new object or a new plot to the
#' session. Graph of steps is easier to read for humans than a graph of
#' commits becase only the relevant (new) information is shown in each
#' node of the graph. Thus, translating from commits to steps is the
#' first step to visualize the history stored in commits.
#'
#' `graph_to_steps` is the main function that orchestrates the
#' transformation.
#'
#' @param graph Object returned by [graph()].
#' @return Object of S3 class `steps`.
#'
#' @rdname steps_internal
#'
graph_to_steps <- function (graph)
{
  stopifnot(is_graph(graph))

  # convert each single commit
  all <- lapply(graph, function (commit) {
    new_objects <- introduced_in(graph, commit$id)
    if (!length(new_objects)) return(NULL)
    commit_to_steps(commit, new_objects)
  })
  out <- vapply(all, is.null, logical(1))
  all <- all[!out]

  steps <- unlist(lapply(all, `[[`, i = 'steps'), recursive = FALSE)
  links <- unlist(lapply(all, `[[`, i = 'links'), recursive = FALSE)

  find_parent <- function (id)
  {
    parent <- graph[[id]]$parent
    if (is.na(parent) || length(all[[parent]]$steps)) return(parent)
    return(find_parent(parent))
  }

  # connect the last object of each "parent" commit with the first
  # object of each of its "children"
  bridges <- unname(lapply(graph[!out], function (commit) {
    parent <- find_parent(commit$id)
    if (is.na(parent)) return(NULL)
    list(
      source = last(all[[parent]]$steps)$id,
      target = first(all[[commit$id]]$steps)$id
    )
  }))
  bridges <- bridges[!vapply(bridges, is.null, logical(1))]
  links <- c(links, bridges)

  # return the final "steps" structure
  structure(list(steps = unname(steps), links = unname(links)),
            class = 'steps')
}


#' @description `is_steps` verifies if the given object is a valid
#' `steps` structure.
#'
#' @param x Object to be verified.
#'
#' @rdname steps
#'
is_steps <- function (x) inherits(x, 'steps')


#' Interactive history.
#'
#' @description `plot.steps` open an interactive history viewer.
#' @param x The `steps` history object to be printed or viewed.
#' @param ... Extra arguments for printing/plotting.
#'
#' @export
#' @rdname steps
#'
plot.steps <- function (x, ...)
{
  input <- list(data = x)
  # create the widget
  htmlwidgets::createWidget("experiment", input, width = NULL, height = NULL)
}


#' @description `plot.steps` open an interactive history viewer.
#'
#' @export
#' @rdname steps
#'
print.steps <- function(x, ...)
{
  cat("A `steps` history object, contains ", length(x$steps), " step(s).\n")

  type <- vapply(x$steps, `[[`, character(1), i = 'type')
  cat(sum(type == 'object'), " object(s) and ", sum(type == 'plot'), " plot(s)\n")

  invisible(x)
}


#' @description `commit_to_steps` generates a `list` with two elements:
#' * `steps` with a separate entry for each variable/plot that matches
#'   the `objects` filter
#' * `links` which defines links (graph edges) between `steps`
#'
#' @param commit A [commit()] object.
#' @param objects Filter for objects present in the commit.
#' @return `commit_to_steps` returns a `list` of `steps` and `links`.
#'
#' @rdname steps_internal
#'
commit_to_steps <- function (commit, objects)
{
  # turns an object/plot into a step structure
  generate_step <- function(name, id, object) {
    if (identical(name, '.plot')) {
      list(
        type = 'plot',
        id   = id,
        expr = format_expression(commit$expr),
        contents = as.character(object)
      )
    }
    else {
      list(
        name = name,
        type = "object",
        id   = id,
        expr = format_expression(commit$expr),
        desc = description(object)
      )
    }
  }

  # define the TRUE/FALSE filter
  filter <- names(commit$objects) %in% objects

  names <- names(commit$objects)[filter]
  ids <- as.character(commit$object_ids)[filter]
  objects <- commit$objects[filter]

  # get all steps
  steps <- mapply(generate_step, name = names, id = ids, object = objects,
                  SIMPLIFY = FALSE, USE.NAMES = FALSE)

  # get links between these teps
  links <- mapply(function (source, target) list(source = source, target = target),
                  source = head(ids, -1), target = tail(ids, -1),
                  SIMPLIFY = FALSE, USE.NAMES = FALSE)

  list(steps = steps, links = links)
}


#' @description `introduced_in` generates the filter for
#' `commit_to_steps`'s `objects` parameter. It does it by comparing the
#' contents of the commit `id` against the contents of its parent.
#'
#' @param id Identifier of a commit in `graph`.
#' @return `introduced_in` returns a `character` vector.
#'
#' @rdname steps_internal
#'
introduced_in <- function (graph, id)
{
  c <- graph[[id]]
  if (is.na(c$parent)) return(names(c$objects))

  p <- graph[[c$parent]]
  new_objs <- Filter(function (n) {
    is.na(match(n, names(p$objects))) || !identical(c$object_ids[[n]], p$object_ids[[n]])
  }, setdiff(names(c$objects), '.plot'))

  # there is a plot (first condition) and it's different from
  # what was there before (second condition)
  if (!is.null(c$object_ids$.plot) &&
      !identical(c$object_ids$.plot, p$object_ids$.plot))
  {
    return(c(new_objs, '.plot'))
  }

  new_objs
}


#' @description `read_objects` reads every object/plot and fills in the
#' `contents` or `desc`ription. It is particularly useful when initial
#' `steps` graph has been read without objects' contents, e.g. in
#' [query_by].
#'
#' @rdname steps_internal
#'
read_objects <- function (s, store)
{
  s$steps <- lapply(s$steps, function (step) {
    if (!is_empty(step$contents) || !is_empty(step$desc)) return(step)
    obj <- storage::os_read_object(store, step$id)

    if (identical(step$type, 'object')) {
      step$desc <- description(obj)
    }
    else {
      step$contents <- as.character(obj)
    }

    step
  })

  s
}


#' @description `find_root_id` searches for the single commit
#' in the graph without a parent.
#'
#' @rdname steps_internal
#'
find_root_id <- function (g)
{
  stopifnot(is_graph(g))
  root <- names(Filter(function (co) is.na(co$parent), g))

  stopifnot(length(root) == 1)
  root
}


#' @description `format` prepares the expression for display
#' in a HTML page.
#'
#' @import formatR
#' @rdname steps_internal
#'
format_expression <- function (code)
{
  return(paste(deparse(code), sep = '\n'))

  form <- tryCatch(formatR::tidy_source(text = code, blank = FALSE, comment = FALSE,
                                        width.cutoff = 72,
                                        output = FALSE),
                   error = function(e) 'error')
  if (!identical(form, 'error')) return(form$text.tidy)
}


#' @description `description` format the expression for display
#' in a HTML page.
#'
#' @import broom
#' @rdname steps_internal
#'
description <- function (object)
{
  if (is_empty(object)) return(NA_character_)

  if (is.data.frame(object)) return(paste0('data.frame [', nrow(object), ', ', ncol(object), ']'))

  if (inherits(object, 'lm')) {
    g <- glance(object)
    return(paste('adj R2:', format(g$adj.r.squared, digits = 2),
                 'AIC: ', format(g$AIC, digits = 2),
                 'df: ', g$df))
  }

  paste(class(object), collapse = '.')
}


#' Compare two SVG images.
#'
#' SVG images are processed in this package as base64-encoded, XML text
#' data. When produced, certain differences are introduced in XML
#' attributes that have no effect on the final plots. That is why,
#' however, SVG plots need to be compared graphically and not textually.
#' This function produces a thumbnail of each SVG image and then
#' compares the raster graphic.
#'
#' @param a First SVG image.
#' @param b Second SVG image.
#' @return `TRUE` if SVGs are the same plot-wise.
#'
#' @import rsvg
#' @import jsonlite
#'
svg_equal <- function (a, b)
{
  if (is_empty(a)) return(is_empty(b))
  if (is_empty(b)) return(FALSE)

  a <- try(rsvg(base64_dec(a), 100, 100), silent = TRUE)
  b <- try(rsvg(base64_dec(b), 100, 100), silent = TRUE)
  if (is_error(a) && is_error(b)) return(TRUE)

  isTRUE(all.equal(a, b))
}




#' @import jsonlite
graph_to_json <- function (g)
{
  stopifnot(is_graph(g))
  steps <- graph_to_steps(g)
  jsonlite::toJSON(steps, pretty = TRUE, auto_unbox = TRUE)
}

find_first_parent <- function (g, id)
{
  g <- Filter(function (co) (id %in% co$object_ids), g)
  i <- which.min(vapply(g, function (co) co$level, numeric(1)))
  if (!length(i)) return(NULL)
  g[[i]]
}
