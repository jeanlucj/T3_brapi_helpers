save_archived_vcf <- function(project_id, file_name, prefix){
  suffix <- stringr::str_extract(file_name, "file.*$")
  file_name_vcf <- paste0(prefix, "_genotypes_",
                          project_id, "_",
                          suffix, ".vcf")
  # file_name_vcf <- here::here("data", file_name_vcf)
  vcf_status <- wheat_conn$vcf_archived(output=file_name_vcf,
                                        genotyping_project_id = project_id,
                                        file_name = file_name)
  if (vcf_status$status$category != "Success"){
    cat("Unsuccessful VCF download. Project ID", project_id, "File Name", file_name, "\n")
  }
  return(file_name_vcf)
}
