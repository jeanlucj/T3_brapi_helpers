#' Convert a BrAPI germplasm result into a single-row data frame
#'
#' Takes a single germplasm object from a BrAPI germplasm search and converts
#' it into a one-row \code{data.frame} with key identifiers and synonym
#' metadata.
#'
#' @param gr A list representing a single germplasm result from a BrAPI
#'   germplasm search.
#' @param study_id The studyDbId (character or numeric) associated with this
#'   germplasm in the current context.
#'
#' @return A one-row \code{data.frame} with columns \code{study_db_id},
#'   \code{germplasm_db_id}, \code{germplasmName}, and \code{synonym}.
#'
#' @details If synonyms are present, only the first synonym is extracted.
#'
make_row_from_germ_result <- function(gr, study_id){
  return(
    data.frame(
      study_db_id = study_id,
      germplasm_db_id = gr$germplasmDbId %||% NA,
      germplasm_name = gr$germplasmName %||% NA,
      synonym = if (!is.null(gr$synonyms) && length(gr$synonyms) > 0){
        gr$synonyms[[1]]$synonym %||% NA
      } else{
        NA
      },
      stringsAsFactors = FALSE
    )
  )
}

#' Get germplasm metadata for a single trial via BrAPI
#'
#' Queries the BrAPI \code{/search/germplasm} endpoint for a given trial and
#' returns a data frame of germplasm accessions associated with that trial
#'
#' @param study_id A single studyDbId to query germplasm for.
#' @param brapi_connection A BrAPI connection object, typically from
#'   \code{BrAPI::createBrAPIConnection()}, with a \code{$search()} method.
#' @param verbose Logical; if \code{TRUE}, print messages about the retrieval
#'   process.
#'
#' @return A data frame of germplasm metadata for the given trial, with one
#'   row per germplasm. Columns include \code{study_db_id}, \code{germplasm_db_id},
#'   \code{germplasmName}, and \code{synonym}. If no result is found, not sure
#'   what happens.
#'
#' @importFrom dplyr bind_rows
#'
#' @examples
#' \dontrun{
#' brapi_conn <- BrAPI::createBrAPIConnection("wheat-sandbox.triticeaetoolbox.org", is_breedbase = TRUE)
#'
#' germ_df <- get_germplasm_from_single_trial("8128", brapi_conn)
#' germ_df
#' }
#'
#' @export
get_germplasm_from_single_trial <- function(study_id, brapi_connection, verbose=F){

  get_fields_from_data <- function(data_list){
    if (verbose) cat("Retrieved metadata on", data_list$germplasmName, "\n")
    return(tibble(study_db_id=study_id,
                  germplasm_db_id=data_list$germplasmDbId,
                  germplasm_name=data_list$germplasmName,
                  synonyms=data_list$synonyms |> unlist() |> list(),
                  pedigree=data_list$pedigree))
  }

  search_result <- brapi_connection$search("germplasm",
                                          body = list(studyDbIds = study_id))

  # Make a data.frame from the combined data
  return(lapply(search_result$combined_data, get_fields_from_data) |>
           dplyr::bind_rows() |>
           dplyr::distinct() |>
           janitor::clean_names())
}

#' Get germplasm metadata for multiple trials
#'
#' Wrapper around \code{\link{get_germplasm_from_single_trial}} to retrieve and combine
#' germplasm metadata for a vector of trial IDs.
#'
#' @param study_id_vec A character vector of studyDbIds to query.
#' @param brapi_connection A BrAPI connection object as used in
#'   \code{get_germplasm_from_single_trial()}.
#' @param verbose Logical; passed on to \code{get_germplasm_from_single_trial()} to
#'   control logging. If FALSE display purrr progress bar
#'
#' @return A data frame obtained by row-binding the results of each trial, with
#'   one row per germplasm per trial
#'
#' @importFrom dplyr bind_rows
#'
#' @examples
#' \dontrun{
#' brapi_conn <- BrAPI::getBrAPIConnection("T3/Wheat")
#'
#' all_germ <- T3_brapi_helpers::get_germplasm_from_trial_vec(
#'   c("10673", "10677"), brapi_conn)
#' all_germ
#' }
#'
#' @export
get_germplasm_from_trial_vec <- function(study_id_vec, brapi_connection, verbose=F){

  germ_meta_list <- purrr::map(
    study_id_vec,
    get_germplasm_from_single_trial,
    brapi_connection = brapi_connection,
    verbose = verbose,
    .progress = !verbose
  )

  return(dplyr::bind_rows(germ_meta_list) |>
           janitor::clean_names())
}

#' Get genotyping protocol metadata for a single germplasm
#'
#' Queries the T3 AJAX interface using the \code{$wizard()} method of a
#' brapi_connection to determine which genotyping protocols have been used for a
#' specific germplasm
#'
#' @param germ_id The germplasmDbId for the accession of interest.
#' @param brapi_connection A BrAPI connection object, typically from
#'   \code{BrAPI::createBrAPIConnection()}, with a \code{$wizard()} method.
#' @param verbose Logical; if TRUE, prints progress messages.
#'
#' @return A tibble with a single row containing
#'   \code{germplasm_db_id}, \code{genoProtocol_db_id}, and \code{genoProtocolName}.
#'   The genotyping protocol columns are list columns, potentially containing
#'   multiple protocol IDs/names.
#'
#' @importFrom httr POST content timeout
#' @importFrom tibble tibble
#'
#' @examples
#' \dontrun{
#' brapi_conn <- BrAPI::createBrAPIConnection("wheat-sandbox.triticeaetoolbox.org", is_breedbase = TRUE)
#'
#' winner_geno_protocols <- get_geno_protocol_from_germ_vec("1284387", brapi_conn)
#' winner_geno_protocols
#' }
#'
#' @export
get_geno_protocol_from_single_germ <- function(germ_id, brapi_connection, verbose=F){

  if (verbose){
    cat("Getting genotyping protocols for germplasmDbId", germ_id, "\n")
  }

  protocols <- brapi_connection$wizard("genotyping_protocols",
                                      list(accessions=germ_id))
  protocols <- protocols$content$list

  # Get ALL protocols used to genotype the germplasm
  # The |> unlist() |> list() maneuver turns a list of several into a list
  # with one vector in it.
  if (length(protocols) > 0) {
    protocol_id <- lapply(protocols, function(pl) as.character(pl[[1]])) |>
      unlist() |> list()
    protocol_name <- lapply(protocols, function(pl) as.character(pl[[2]])) |>
      unlist() |> list()
  } else {
    protocol_id <- list(NA)
    protocol_name <- list(NA)
  }

  this_row <- tibble::tibble(
    germplasm_db_id = germ_id,
    genoProtocol_db_id = protocol_id,
    genoProtocolName = protocol_name
  )

  return(this_row)
}

#' Determine genotyping protocol metadata for a set of accessions
#'
#' Wrapper for get_geno_protocol_from_single_germ.
#'
#' @param germ_id_vec A vector of germplasm DbIds.
#' @param brapi_connection A BrAPI connection object, typically from
#'   \code{BrAPI::createBrAPIConnection()}, with a \code{$wizard()} method.
#' @param verbose Logical; if \code{FALSE} (default), display purrr progress bar
#'   else print for each \code{germplasmDbId}
#'
#' @return A tibble with one row per germplasm, including genotyping protocol
#'   IDs and names as list columns.
#'
#' @importFrom purrr map
#' @importFrom dplyr bind_rows
#'
#' @examples
#' \dontrun{
#' brapi_conn <- BrAPI::createBrAPIConnection("wheat-sandbox.triticeaetoolbox.org", is_breedbase = TRUE)
#'
#' germ_geno_protocols <- get_geno_protocol_from_germ_vec(
#'   c("1284387", "1382716", "1415479"), brapi_conn)
#' germ_geno_protocols
#' }
#'
#' @export
get_geno_protocol_from_germ_vec <- function(germ_id_vec, brapi_connection, verbose=F) {

  return(purrr::map(germ_id_vec,
                    get_geno_protocol_from_single_germ,
                    brapi_connection=brapi_connection,
                    verbose=verbose,
                    .progress=!verbose) |>
           dplyr::bind_rows() |>
           janitor::clean_names())
}

#' Get trial metadata for all trials in which a single germplasm was evaluated
#'
#' Queries the BrAPI \code{/search/studies} endpoint for a given germplasm and
#' returns a data frame of trials associated with that germplasm
#'
#' @param germplasm_id A single germplasmDbId to query trials for.
#' @param brapi_connection A BrAPI connection object, from
#'   \code{BrAPI::createBrAPIConnection()}.
#' @param verbose Logical; if \code{TRUE}, print messages about the retrieval
#'   process.
#'
#' @return A data frame of trial metadata for the given germplasm, with one
#'   row per trial. Columns include \code{germplasm_db_id}, \code{study_db_id}, and
#'   \code{studyName}. If no result is found, not sure what happens.
#'
#' @importFrom dplyr bind_rows
#'
#' @examples
#' \dontrun{
#' brapi_conn <- BrAPI::createBrAPIConnection("wheat.triticeaetoolbox.org", is_breedbase = TRUE)
#'
#' trial_df <- get_trial_from_single_germplasm("1284387", brapi_conn)
#' trial_df
#' }
#'
#' @export
get_trial_from_single_germplasm <- function(germplasm_id, brapi_connection,
                                        verbose=F){

  get_fields_from_data <- function(data_list){
    if (verbose) cat("Retrieved metadata on", data_list$studyName, "\n")
    return(tibble::tibble(germplasm_db_id=germplasm_id,
                  study_db_id=data_list$studyDbId,
                  study_name=data_list$studyName))
  }

  search_result <- brapi_connection$search("studies",
                                    body = list(germplasmDbIds = germplasm_id))

  # Make a data.frame from the combined data
  return(lapply(search_result$combined_data, get_fields_from_data) |>
           dplyr::bind_rows() |>
           dplyr::distinct() |>
           janitor::clean_names())
}

#' Get trial metadata for multiple germplasms
#'
#' Wrapper around \code{\link{get_trial_from_single_germplasm}} to retrieve and
#' combine trial metadata for a vector of germplasm IDs.
#'
#' @param germplasm_id_vec A character vector of germplasmDbIds to query.
#' @param brapi_connection A BrAPI connection object as used in
#'   \code{get_trial_from_single_germplasm()}.
#' @param verbose Logical; passed on to \code{get_trial_from_single_germplasm()} to
#'   control logging. If FALSE display purrr progress bar
#'
#' @return A data frame obtained by row-binding the results of each germplasm,
#'   with one row per trial per germplasm
#'
#' @importFrom dplyr bind_rows
#'
#' @examples
#' \dontrun{
#' brapi_conn <- BrAPI::createBrAPIConnection("wheat.triticeaetoolbox.org", is_breedbase = TRUE)
#'
#' all_trial <- get_trial_from_germplasm_vec(c("1284387", "1382716"), brapi_conn)
#' all_trial
#' }
#'
#' @export
get_trial_from_germplasm_vec <- function(germplasm_id_vec, brapi_connection,
                                     verbose=F){

  germ_meta_list <- purrr::map(
    germplasm_id_vec,
    get_trial_from_single_germplasm,
    brapi_connection = brapi_connection,
    verbose = verbose,
    .progress = !verbose
  )

  return(dplyr::bind_rows(germ_meta_list) |> janitor::clean_names())
}
