#' State object.
#' 
#' \describe{
#'   \item{last}{Stores handles to all objects in the global namespace
#'     at the time of the last commit.}
#'   \item{tracking}{whether we are in the tracking state}
#'   \item{old_prompt}{prompt as set when loading the package}
#' }
#' 
state <- new.env()
state$tracking   <- TRUE
state$last       <- list()
state$old_prompt <- ''



#' Set tracking mode to ON/OFF.
#' 
#' @export
#' 
tracking_on <- function () {
  state$tracking <- TRUE
  update_prompt(state$tracking)
}


#' @name tracking_on
#' @export
tracking_off <- function () {
  state$tracking <- FALSE
  update_prompt(state$tracking)
}


#' Updates the prompt according to \code{state$tracking}.
#' 
update_prompt <- function (on_off) {
  if (on_off)
    options(prompt = "tracking > ")
  else
    options(prompt = "not tracking > ")
}



# Creating a new commit/checkout:
#
#  1. get the last commit
#  2. get the list of object names and see if any of them overlap with
#     the last commit
#  3. those that overlap we already have hashed in the last commit
#  4. those that have the same names but new contents need to be hashed
#  5. all new objects need to be hashed
#  6. put in the new commit:
#       - all names and their hashes
#       - the hash (id) of the last commit
#       - the contents of the history line (command) associated with creating
#         this new commit
#     (do we create a commit if none of the objects were changed? if the
#      history line is just printing something or opening help? rather not)
#  7. put the commit in the storage space
#  8. store all new objects and the commit object in the storage space

#' A callback run after each top-level expression is evaluated.
#'  
#' From \link{\code{addTaskCallback}}: if the data argument was
#' specified in the call to addTaskCallback, that value is given as the
#' fifth argument.
#'
#' @param expression Expression for the top-level task.
#' @param result Result of the top-level task.
#' @param successful A logical value indicating whether it was
#'        successfully completed or not (always \code{TRUE} at present).
#' @param printed A logical value indicating whether the result was
#'        printed or not.
#'
#' @return A logical value indicating whether to keep this function in
#'         the list of active callback.
update_current_commit <- function (expression, result, successful, printed)
{
  TRUE
}


#' Add hash attribute to each object in environment.
#' 
#' @param env Environment to process.
update_with_hash <- function (env)
{
  lapply(ls(envir = env), function(name) {
    attr(env[[name]], hash_attribute_name) <- hash(env[[name]])
  })
  invisible()
}
