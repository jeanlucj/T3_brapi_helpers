#' Convert a BrAPI study result into a single-row data frame
#'
#' Takes a single study object from a BrAPI `studies` response and converts it
#' into a one-row \code{data.frame} with key metadata fields. This is a helper
#' used by functions that assemble trial metadata tables.
#'
#' @param tr A list representing a single trial result from a BrAPI
#'   \code{/studies} endpoint, typically \code{brapi_connection$get("studies/ID")$content$result}.
#'
#' @return A one-row \code{data.frame} with columns such as
#'   \code{study_db_id}, \code{studyName}, \code{studyType},
#'   \code{studyDescription}, \code{locationName}, \code{trial_db_id},
#'   \code{startDate}, \code{endDate}, \code{programName},
#'   \code{commonCropName}, and \code{experimentalDesign}.
#'
#' @details This function assumes the infix operator \code{\%||\%} is available
#'   in the calling environment to replace \code{NULL} with \code{NA}.
#'
make_row_from_trial_result <- function(tr){
  toRet <- tibble::tibble(
    study_db_id = tr$studyDbId %||% NA_integer_,
    study_name = tr$studyName %||% NA_character_,
    study_type = tr$studyType %||% NA_character_,
    study_description = tr$studyDescription %||% NA_character_,
    location_name = tr$locationName %||% NA_character_,
    trial_db_id = tr$trialDbId %||% NA_integer_,
    start_date = tr$startDate %||% NA,
    end_date = tr$endDate %||% NA,
    program_name = tr$additionalInfo$programName %||% NA_character_,
    common_crop_name = tr$commonCropName %||% NA_character_,
    experimental_design = tr$experimentalDesign$description,
    create_date = tr$additionalInfo$createDate %||% NA
  )
  toRet <- toRet |> dplyr::mutate(
    start_date = as.POSIXct(start_date, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    end_date = as.POSIXct(end_date, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    create_date = as.POSIXct(create_date, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
  return(toRet)
}

#' Retrieve metadata for a set of trials by study IDs
#'
#' Given a vector of BrAPI study IDs, query the \code{/studies/{studyDbId}}
#' endpoint for each and compile a tidy data frame of trial metadata.
#'
#' @param study_id_vec A character vector of BrAPI study IDs (studyDbId values)
#'   to query.
#' @param brapi_connection A BrAPI connection object, typically created by
#'   \code{BrAPI::createBrAPIConnection()},
#'   with \code{$get()} method available.
#'
#' @return A tibble-like data frame with one row per trial and cleaned column
#'   names (via \code{janitor::clean_names()}). Date columns \code{start_date}
#'   and \code{end_date} are converted to \code{POSIXct} in UTC.
#'
#' @importFrom dplyr bind_rows mutate
#' @importFrom janitor clean_names
#'
#' @examples
#' \dontrun{
#' brapi_conn <- BrAPI::createBrAPIConnection("wheat-sandbox.triticeaetoolbox.org", is_breedbase = TRUE)
#'
#' # Retrieve metadata for two trials
#' df <- get_trial_meta_data_from_trial_vec(c("8128", "9421"), brapi_conn)
#' df
#' }
#'
#' @export
get_trial_meta_data_from_trial_vec <- function(study_id_vec, brapi_connection){

  get_single_study <- function(id){
    return(brapi_connection$get(paste0("studies/", id))$content$result)
  }

  trials_list <- lapply(study_id_vec, get_single_study)

  trials_df <- trials_list |>
    lapply(make_row_from_trial_result) |>
    dplyr::bind_rows() |>
    janitor::clean_names()

  return(trials_df |> janitor::clean_names())
}

#' Retrieve metadata on all trials for a given crop
#'
#' Queries the BrAPI \code{/search/studies} endpoint for all studies matching
#' a given common crop name, handles polling if needed, and compiles the
#' results into a trial metadata data frame.
#'
#' @param brapi_connection A BrAPI connection object, typically created by
#'   \code{BrAPI::createBrAPIConnection()},
#'   with \code{$search()} method available.
#' @param crop_name A character string giving the BrAPI \code{commonCropName}
#'   to search for (e.g. \code{"wheat"}).
#'
#' @return A tibble-like data frame with one row per trial, containing
#'   standardized trial metadata with cleaned column names and \code{POSIXct}
#'   \code{start_date} and \code{end_date} columns.
#'
#' @importFrom dplyr bind_rows mutate
#' @importFrom janitor clean_names
#'
#' @examples
#' \dontrun{
#' brapi_conn <- BrAPI::createBrAPIConnection("wheat-sandbox.triticeaetoolbox.org", is_breedbase = TRUE)
#'
#' # Retrieve trial metadata for "Wheat"
#' all_trials <- get_all_trial_meta_data(brapi_conn, "Wheat")
#' all_trials
#' }
#'
#' @export
get_all_trial_meta_data <- function(brapi_connection, crop_name){

  ## pull list of all trials from T3
  trials_search <- brapi_connection$search("studies",
    body = list(commonCropNames = crop_name)
  )

  # Compile the BrAPI results into a data frame
  trials_df <- trials_search$combined_data |>
    lapply(make_row_from_trial_result) |>
    dplyr::bind_rows() |>
    janitor::clean_names()

  return(trials_df |> janitor::clean_names())
}

#' Retrieve what traits were measured for a set of trials by study IDs
#'
#' Given a vector of BrAPI study IDs, use the search function of a Breedbase
#' connection to compile a vector of all traits measured in each trial in the
#' study_id_vec
#'
#' @param study_id_vec A character vector of BrAPI study IDs (studyDbId values)
#'   to query.
#' @param brapi_connection A BrAPI connection object, typically created by
#'   \code{BrAPI::createBrAPIConnection()}, with \code{$search()} method.
#' @param id_or_name A string. If "name" return the names of the traits else
#'   return the trait DB IDs.
#' @param verbose A logical. If TRUE a lot of info on the traits in the studies
#'   else a purrr progress bar
#'
#' @return A vector of either trait names or trait DB IDs.
#'
#' @importFrom dplyr if_else
#'
#' @examples
#' \dontrun{
#' brapi_conn <- BrAPI::createBrAPIConnection("wheat-sandbox.triticeaetoolbox.org", is_breedbase = TRUE)
#'
#' traits <- get_traits_from_trial_vec(c("8128", "9421"), brapi_conn)
#' traits
#' }
#'
#' @export
get_traits_from_trial_vec <- function(study_id_vec, brapi_connection,
                                  id_or_name="name", verbose=F){
  # make tibbles with names and ids for traits in each study
  trial_traits_list <- purrr::map(study_id_vec,
                                get_traits_from_single_trial,
                                brapi_connection=brapi_connection,
                                verbose=verbose,
                                .progress=!verbose)
  # Compile a tibble with either names or ids in one cell
  id_or_name <- ifelse(id_or_name == "name", 2, 1)
  make_study_id_row <- function(idx){
    return(tibble::tibble(study_id=study_id_vec[idx],
                          traits=list(trial_traits_list[[idx]][, id_or_name])))
  }

  return(lapply(1:length(study_id_vec), make_study_id_row) |>
           dplyr::bind_rows() |>
           janitor::clean_names())
}

#' Get traits measured from a single trial via BrAPI
#'
#' Queries the BrAPI \code{/search/variables} endpoint for a given trial and
#' returns a data frame of traits and their DbIds measured in that trial
#'
#' @param study_id A single studyDbId to query germplasm for.
#' @param brapi_connection A BrAPI connection object, typically from
#'   \code{BrAPI::createBrAPIConnection()}, with a \code{$search()} method.
#' @param verbose Logical; if \code{TRUE}, print messages about the retrieval
#'   process.
#'
#' @return A data frame of traits for the given trial, with one row per trait
#'   Columns include \code{observationVariable_db_id} and
#'   \code{observation_variable_name}. If no result is found, not sure what
#'   happens...
#'
#' @importFrom dplyr bind_rows
#'
#' @examples
#' \dontrun{
#' brapi_conn <- BrAPI::createBrAPIConnection("wheat-sandbox.triticeaetoolbox.org", is_breedbase = TRUE)
#'
#' traits_df <- get_traits_from_single_trial("8128", brapi_conn)
#' traits_df
#' }
#'
#' @export
get_traits_from_single_trial <- function(study_id, brapi_connection, verbose=F){

  get_fields_from_data <- function(data_list){
    if (verbose) cat("Retrieved metadata on",
                     data_list$observationVariableName, "\n")
    return(tibble(observation_variable_db_id=data_list$observationVariableDbId,
                  observation_variable_name=data_list$observationVariableName))
  }

  search_result <- brapi_connection$search("variables",
                                          body = list(studyDbIds = study_id))

  # Make a data.frame from the combined data
  return(lapply(search_result$combined_data, get_fields_from_data) |>
           dplyr::bind_rows() |>
           dplyr::distinct() |>
           janitor::clean_names())
}

#' Get location info from a vector of locations via BrAPI
#'
#' Queries the BrAPI \code{/search/locations} endpoint and
#' returns a data frame of lat, long, and elevation values for those locations
#'
#' @param loc_vec A vector of location names or DB IDs for which you want lat,
#'   long, and elevation values
#' @param brapi_connection A BrAPI connection object, typically from
#'   \code{BrAPI::createBrAPIConnection()}, with a \code{$search()} method.
#' @param id_or_name A string. If "name" will expect loc_vec to be a vector of
#'   location names else a vector of location DB IDs.
#'
#' @return A data frame of lattitude, longitude and elevation values for the
#'   loactions
#'
#' @importFrom dplyr bind_rows
#'
#' @examples
#' \dontrun{
#' brapi_conn <- BrAPI::createBrAPIConnection("wheat.triticeaetoolbox.org", is_breedbase = TRUE)
#'
#' locs_df <- get_lat_long_elev_from_location_vec(c("31", "143"), brapi_conn)
#' locs_df
#' }
#'
#' @export
# I don't know if I'm doing it wrong, but the response is always ALL the
# locations, so I have to filter after
get_lat_long_elev_from_location_vec <- function(loc_vec, brapi_connection,
                                          id_or_name="name"){
  loc_search_to_row <- function(locList){
    coords <- unlist(locList$coordinates$geometry$coordinates)

    dplyr::tibble(
      location_db_id = locList$locationDbId %||% NA,
      location_name = locList$locationName %||% NA,
      abbreviation = locList$abbreviation %||% NA,
      latitude = ifelse(!is.null(coords) & length(coords) >= 2, coords[2], NA),
      longitude = ifelse(!is.null(coords) & length(coords) >= 1, coords[1], NA),
      elevation = ifelse(!is.null(coords) & length(coords) >= 3, coords[3], NA)
    )
  }

  if (id_or_name == "name"){
    loc_search <- brapi_connection$search("locations",
                                         body=list(locationNames = loc_vec))
  } else{
    loc_search <- brapi_connection$search("locations",
                                         body=list(locationDbIds = loc_vec))
  }
  loc_search <- loc_search$combined_data

  loc_df <- lapply(loc_search, loc_search_to_row) |>
    dplyr::bind_rows()

  return(loc_df |> janitor::clean_names())
}
