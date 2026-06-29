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
#' all_germ <- T3BrapiHelpers::get_germplasm_from_trial_vec(
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

#' Get the synonyms of a set of accessions, keyed by primary germplasm name
#'
#' Looks up germplasm records by their **primary** \code{germplasmName} and
#' returns the synonyms recorded for each. This matters when an accession was
#' genotyped under a *preliminary* experimental line name that was later demoted
#' to a synonym after a *final* name was assigned: a VCF (or any other data
#' source) may carry the sample under the synonym while downstream analysis keys
#' on the primary name.
#'
#' Queries the BrAPI \code{/search/germplasm} endpoint with
#' \code{germplasmNames}, batched to keep each request small, and collates the
#' synonyms returned for each matched record.
#'
#' @param germplasm_names Character vector of primary germplasm names to look up.
#' @param brapi_connection A BrAPI connection object, typically from
#'   \code{BrAPI::createBrAPIConnection()}, with a \code{$search()} method.
#' @param batch_size Integer; maximum number of names per BrAPI request
#'   (default 500).
#' @param pause Numeric; seconds to wait between batches, to avoid tripping the
#'   server's rate limit (default 0).
#' @param max_retries Integer; attempts per batch on a transient failure (e.g. an
#'   HTTP 403), with exponential backoff between attempts (default 3).
#' @param verbose Logical; if \code{TRUE}, print per-batch progress messages.
#'
#' @return A tibble with one row per (primary, synonym) pair and columns
#'   \code{primary_name} and \code{synonym}. Accessions with no synonyms (or that
#'   are not found) contribute no rows.
#'
#' @details Synonyms are returned by BrAPI either as bare strings or as objects
#'   with a \code{synonym} field; both shapes are handled. A batch that keeps
#'   failing after \code{max_retries} is warned about and skipped (its accessions
#'   simply contribute no synonym rows) rather than aborting the whole call.
#'
#' @examples
#' \dontrun{
#' brapi_conn <- BrAPI::createBrAPIConnection("wheat.triticeaetoolbox.org", is_breedbase = TRUE)
#' get_synonyms_from_germplasm_names(c("ACC_ONE", "ACC_TWO"), brapi_conn)
#' }
#'
#' @importFrom dplyr bind_rows distinct
#' @importFrom tibble tibble
#' @export
get_synonyms_from_germplasm_names <- function(germplasm_names,
                                              brapi_connection,
                                              batch_size = 500L,
                                              pause = 0,
                                              max_retries = 3L,
                                              verbose = FALSE) {

  germplasm_names <- unique(as.character(germplasm_names))
  germplasm_names <- germplasm_names[!is.na(germplasm_names) &
                                       nzchar(germplasm_names)]
  empty <- tibble::tibble(primary_name = character(0), synonym = character(0))
  if (length(germplasm_names) == 0) return(empty)

  # BrAPI synonyms come back either as bare strings or as {synonym, type}
  # objects; pull just the synonym string from whichever shape is present.
  extract_synonyms <- function(syn) {
    if (is.null(syn) || length(syn) == 0) return(character(0))
    out <- vapply(syn, function(s) {
      if (is.list(s)) {
        v <- s[["synonym"]]
        if (is.null(v)) NA_character_ else as.character(v)[1]
      } else {
        as.character(s)[1]
      }
    }, character(1))
    unique(out[!is.na(out) & nzchar(out)])
  }

  # One request, with retry/backoff. Returns the combined_data list on success,
  # or NULL on persistent failure. A failed BrAPI search returns an atomic value
  # (the 403 warning result), so a non-atomic response that yields combined_data
  # without erroring is the success signal; an empty (NULL) combined_data is a
  # legitimate "no matches" answer.
  fetch_once <- function(names_vec) {
    for (attempt in seq_len(max_retries)) {
      sr <- tryCatch(
        brapi_connection$search("germplasm",
                                body = list(germplasmNames = as.list(names_vec))),
        error = function(e) e)
      if (!inherits(sr, "error") && !is.atomic(sr)) {
        cd <- tryCatch(sr$combined_data, error = function(e) NA)
        if (!identical(cd, NA)) return(list(ok = TRUE, recs = cd))
      }
      if (attempt < max_retries) Sys.sleep(2^attempt)
    }
    list(ok = FALSE, recs = NULL)
  }

  # Fetch a set of names, bisecting on a PERSISTENT failure so one "poison" name
  # (e.g. one whose payload trips a server 403/WAF rule) can't sink its whole
  # batch -- the rest of the chunk's synonyms are still recovered, and only the
  # offending single name is skipped (with a warning).
  fetch_recursive <- function(names_vec) {
    res <- fetch_once(names_vec)
    if (res$ok) return(res$recs)
    if (length(names_vec) <= 1L) {
      warning("germplasm search persistently failed for name: ",
              paste(names_vec, collapse = ", "), " - skipping")
      return(list())
    }
    mid <- length(names_vec) %/% 2L
    c(fetch_recursive(names_vec[seq_len(mid)]),
      fetch_recursive(names_vec[(mid + 1L):length(names_vec)]))
  }

  batches <- split(germplasm_names,
                   ceiling(seq_along(germplasm_names) / batch_size))

  rows <- list()
  for (i in seq_along(batches)) {
    batch <- batches[[i]]
    if (verbose) message(sprintf("  synonym lookup batch %d/%d (%d names)",
                                  i, length(batches), length(batch)))
    recs <- fetch_recursive(batch)
    if (pause > 0 && i < length(batches)) Sys.sleep(pause)
    if (length(recs) == 0) next
    for (x in recs) {
      primary <- x$germplasmName
      if (is.null(primary) || is.na(primary) || !nzchar(primary)) next
      syns <- extract_synonyms(x$synonyms)
      if (length(syns) == 0) next
      rows[[length(rows) + 1L]] <- tibble::tibble(primary_name = primary,
                                                  synonym = syns)
    }
  }

  if (length(rows) == 0) return(empty)
  dplyr::distinct(dplyr::bind_rows(rows))
}

#' Build an alias -> primary lookup vector for a set of accessions
#'
#' Wraps \code{\link{get_synonyms_from_germplasm_names}} into a named character
#' vector that canonicalizes any known alias (primary name OR synonym) back to
#' the primary germplasm name. Pass this to
#' \code{\link{canonicalize_to_primary}} to relabel data (e.g. VCF sample IDs)
#' that may carry accessions under a synonym.
#'
#' @param germplasm_names Character vector of primary germplasm names.
#' @param brapi_connection A BrAPI connection object with a \code{$search()}
#'   method. Ignored when \code{syn_df} is supplied.
#' @param batch_size Integer; passed to
#'   \code{get_synonyms_from_germplasm_names()}.
#' @param verbose Logical; passed through for per-batch progress.
#' @param syn_df Optional precomputed tibble of \code{primary_name}/\code{synonym}
#'   pairs (as returned by \code{get_synonyms_from_germplasm_names()}). When
#'   supplied, no BrAPI query is made -- useful for assembling the lookup from
#'   checkpointed results.
#'
#' @return A named character vector whose names are aliases (every primary name,
#'   mapped to itself, plus every synonym, mapped to its primary) and whose
#'   values are the corresponding primary names.
#'
#' @details Primary names take precedence over synonym aliases of the same
#'   string. If a synonym string maps to more than one distinct primary, the
#'   first is kept and a warning is emitted (preliminary line names are normally
#'   unique, so this should be rare).
#'
#' @examples
#' \dontrun{
#' brapi_conn <- BrAPI::createBrAPIConnection("wheat.triticeaetoolbox.org", is_breedbase = TRUE)
#' lk <- build_synonym_lookup(c("ACC_ONE", "ACC_TWO"), brapi_conn)
#' canonicalize_to_primary(c("PRELIM_123", "ACC_TWO"), lk)
#' }
#'
#' @export
build_synonym_lookup <- function(germplasm_names, brapi_connection = NULL,
                                 batch_size = 500L, verbose = FALSE,
                                 syn_df = NULL) {

  germplasm_names <- unique(as.character(germplasm_names))
  germplasm_names <- germplasm_names[!is.na(germplasm_names) &
                                       nzchar(germplasm_names)]

  if (is.null(syn_df)) {
    syn_df <- get_synonyms_from_germplasm_names(
      germplasm_names, brapi_connection,
      batch_size = batch_size, verbose = verbose)
  }

  # Primaries first so they win any collision with a synonym of the same string.
  alias   <- c(germplasm_names, syn_df$synonym)
  primary <- c(germplasm_names, syn_df$primary_name)

  keep <- !duplicated(alias)
  dup_aliases <- unique(alias[duplicated(alias)])
  collisions <- dup_aliases[vapply(dup_aliases, function(a)
    length(unique(primary[alias == a])) > 1L, logical(1))]
  if (length(collisions) > 0) {
    warning(length(collisions),
            " alias string(s) map to multiple primaries; keeping first: ",
            paste(utils::head(collisions, 10L), collapse = ", "))
  }

  lookup <- primary[keep]
  names(lookup) <- alias[keep]
  lookup
}

#' Canonicalize identifiers to primary germplasm names
#'
#' Replaces each identifier with its primary germplasm name when it is a known
#' alias (primary or synonym); identifiers absent from the lookup are returned
#' unchanged.
#'
#' @param sample_ids Character vector of identifiers (e.g. VCF sample names).
#' @param alias_lookup A named character vector as returned by
#'   \code{\link{build_synonym_lookup}} (names = aliases, values = primaries). An
#'   empty vector returns \code{sample_ids} unchanged (fail-soft).
#'
#' @return A character vector the same length as \code{sample_ids}, with known
#'   aliases relabeled to their primary name.
#'
#' @export
canonicalize_to_primary <- function(sample_ids, alias_lookup) {
  if (length(alias_lookup) == 0) return(sample_ids)
  hit <- alias_lookup[sample_ids]
  ifelse(is.na(hit), sample_ids, unname(hit))
}
