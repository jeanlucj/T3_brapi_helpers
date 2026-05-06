#' For a study_id, find other studies having a minimum number common accessions
#'
#' For a BrAPI study ID, get the germplasm evaluated in it
#'   Find other studies where those same germplasms were evaluated
#'   Select studies where a minimum number of germplasms are in common with the
#'   focal study ID
#'
#' @param study_id A BrAPI study IDs to query
#' @param brapi_conn A BrAPI connection object, created by
#'   \code{BrAPI::createBrAPIConnection()}
#' @param min_germ_common An integer of the minimum number of germplasms in
#'   common for the study to be included in the response
#'
#' @return A tibble with one row per trial
#'   other_studies: the study_db_id and
#'   n: the number of germplasms in common with the focal study
#'
#' @importFrom janitor tabyl
#' @importFrom dplyr filter rename select
#'
#' @examples
#' \dontrun{
#' brapi_conn <- BrAPI::createBrAPIConnection("T3/Wheat", is_breedbase = TRUE)
#'
#' # Retrieve other studies based on a focal study
#' df <- find_other_studies_evaluating_same_germplasm("10674", brapi_conn)
#' df
#' }
#'
#' @export
find_other_studies_evaluating_same_germplasm <- function(study_id, brapi_conn,
                                                         min_germ_common=5){
  this_study_germ <-
    T3_brapi_helpers::get_germplasm_from_single_trial(study_id, brapi_conn)

  get_trial_ids_from_germplasm_id <- function(germplasm_id, brapi_conn){
    return(brapi_conn$wizard(data_type = "trials",
                             filters=list(accessions=germplasm_id))$data$ids)
  }

  other_studies <- this_study_germ$germplasm_db_id |>
    purrr::map(.f=get_trial_ids_from_germplasm_id,
               brapi_conn=brapi_conn,
               .progress=TRUE)

  other_studies_tabyl <- janitor::tabyl(unlist(other_studies)) |>
    dplyr::select(-percent) |>
    dplyr::rename(other_study_db_id=`unlist(other_studies)`) |>
    dplyr::filter(other_study_db_id != study_id) |>
    dplyr::filter(n >= min_germ_common)

  return(other_studies_tabyl)
}

#' Save predictions from a user-provided prediction function into the file
#' structure needed for the T3 Predictathon 2026
#'
#' If you have a prediction function that takes a study ID and a CV0 or CV00
#' indicator, this function will run predictions and return the proper file
#' structure to submit to the Predictathon folks at T3
#'
#' @param prediction_function A function that takes two inputs:
#'   "study_id": a string that identifies the trial to be predicted.  You can
#'   write the function so that it takes the studyDbId or the studyName
#'   "type_of_cv": a string that is either "CV0" or "CV00" indicating whether
#'   this is a CV0 or CV00 prediction task
#'   The function should return a list with objects
#'   "predictions": a data.frame with two columns: "germplasmName" and
#'     "prediction"
#'   "trials": a vector of the names of the trials used in training
#'   "accessions": a vector of the names of accessions used in training
#' @param id_or_name A string indicating whether your prediction function needs
#'   the trial to be predicted to be identified by its name (id_or_name="name")
#'   or by its T3/Wheat studyDbId (id_or_name="ID", which is the default)
#' @param base_directory A string with the path to the directory where you want
#'   prediction function outputs to be stored
#'
#' @return A string with the path to the base directory in which all prediction
#'   files are stored.
#'
#' @importFrom tibble tibble
#' @importFrom purrr pmap
#' @importFrom readr write_csv
#'
#' @examples
#' \dontrun{
#' # This is a dummy prediction function that  creates generic and random values
#' # for the outputs that a real prediction function would have to create. The
#' # output is a list.  If your prediction makes a list with the same objects,
#' # it will work with the "make_predictathon_file_structure" function.
#'
#' dummy_pred_func <- function(study_id, type_of_cv){
#'   accession_names <- paste0("focal_accession_", study_id, "_", 1:100)
#'   predictions <- tibble::tibble(germplasmName=accession_names,
#'                                 prediction=rnorm(100))
#'   trials <- paste0("training_trial_", type_of_cv, "_", study_id, "_", 1:5)
#'   accessions <- paste0("training_accession_", study_id, "_", 101:300)
#'   return(list(predictions=predictions, trials=trials, accessions=accessions))
#' }
#'
#' # Give your prediction function to the make_predictathon_file_structure
#' # function and tell it whether you want trials to be predicted to be identified
#' # by their name or by the T3/Wheat studyDbId.
#'
#' base_dir <- make_predictathon_file_structure(dummy_pred_func, id_or_name="ID")
#' list.files(path = base_dir, recursive = TRUE)
#' }
#'
#' @export
make_predictathon_file_structure <- function(prediction_function,
                                             id_or_name="ID",
                                             base_directory="~"){
  study_db_ids <- 10673:10681
  study_names <- c("2025_AYT_Aurora", "24Crk_AY2-3", "25_Big6_SVREC_SVREC",
                   "CornellMaster_2025_McGowan", "YT_Urb_25", "AWY1_DVPWA_2024",
                   "OHRWW_2025_SPO", "TCAP_2025_MANKS", "STP1_2025_MCG")

  # Determine whether to use the studyDbId or the studyName as the identifier
  # for the user-provided prediction function
  if (id_or_name == "ID"){
    use_as_identifier <- study_db_ids
  } else{
    use_as_identifier <- study_names
  }

  # Make the complete list of prediction tasks: all nine test trials and both
  # CV0 and CV00 cross validation constraints
  prediction_tasks <- tibble::tibble(
    study_id=rep(use_as_identifier, each=2),
    type_of_cv=rep(c("CV0", "CV00"), times=length(use_as_identifier)),
  )

  # Get the predictions using the user-provided prediction function
  all_prediction_results <- purrr::pmap(
    prediction_tasks,
    prediction_function
  )

  # Make directories and files as requested at
  # https://wheat.triticeaetoolbox.org/guides/t3-prediction-challenge
  base_directory <- paste0(base_directory, "/T3Predictathon2026")
  dir.create(base_directory)

  # Write the results to a folder in the base directory
  prediction_result_index <- 1
  for (trial_directory in study_names){
    with_base <- paste0(base_directory, "/", trial_directory)
    dir.create(with_base)
    for (type_of_cv in c("CV0", "CV00")){
      file_name <- paste0(with_base, "/", type_of_cv, "_Predictions.csv")
      readr::write_csv(
        all_prediction_results[[prediction_result_index]]$predictions,
        file_name
      )
      file_name <- paste0(with_base, "/", type_of_cv, "_Trials.csv")
      readr::write_csv(
        tibble::tibble(
          trainging_trials=all_prediction_results[[prediction_result_index]]$trials
        ),
        file_name
      )
      file_name <- paste0(with_base, "/", type_of_cv, "_Accessions.csv")
      readr::write_csv(
        tibble::tibble(
          trainging_accessions=all_prediction_results[[prediction_result_index]]$accessions
        ),
        file_name
      )
      prediction_result_index <- prediction_result_index + 1
    }
  }

  return(base_directory)
}#END make_predictathon_file_structure
