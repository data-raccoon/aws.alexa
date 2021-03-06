#' @title aws.alexa: R Client for the Alexa Web Information Services API
#' 
#' @name aws.alexa-package
#' @aliases aws.alexa
#'
#' @description Find information about domains, including the kind of content that they carry, how popular are they, sites linking to them, among other things.
#' The package provides access to the Alexa Web Information Service API: \url{http://docs.aws.amazon.com/AlexaWebInfoService/latest/}. 
#'
#' To learn how to use aws.alexa, see this vignette: \url{vignettes/overview.html}. 
#' 
#' You need to get credentials (Access Key ID and Secret Access Key) to use this application. 
#' If you haven't already, get these at \url{https://aws.amazon.com/}. 
#' And set these using \code{\link{set_secret_key}}
#' 
#' @importFrom stats setNames
#' @importFrom httr GET content stop_for_status add_headers
#' @importFrom xml2 read_xml as_list
#' @importFrom dplyr bind_rows
#' @importFrom aws.signature signature_v4_auth locate_credentials
#' @docType package
#' @author Gaurav Sood
NULL


#' 
#' Base POST AND GET functions. Not exported.

#'
#' GET
#' 
#' @param query query list 
#' @param key A character string containing an AWS Access Key ID. The default is retrieved from \code{Sys.getenv("AWS_ACCESS_KEY_ID")}.
#' @param secret A character string containing an AWS Secret Access Key. The default is retrieved from \code{Sys.getenv("AWS_SECRET_ACCESS_KEY")}.
#' @param verbose A logical indicating whether to be verbose. Default is given by \code{options("verbose")}.
#' @param session_token Optionally, a character string containing an AWS temporary Session Token. If missing, defaults to value stored in environment variable \env{AWS_SESSION_TOKEN}.
#' @param region A character string containing the AWS region. If missing, defaults to \dQuote{us-west-1}.
#' @param headers A list of request headers for the REST call. 
#' @param \dots Additional arguments passed to \code{\link[httr]{GET}}.
#' @return list

alexa_GET <- function(query, 
                      key = Sys.getenv("AWS_ACCESS_KEY_ID"),
                      secret = Sys.getenv("AWS_SECRET_ACCESS_KEY"), 
                      verbose = getOption("verbose", FALSE),
                      session_token = NULL,
                      region = 'us-west-1',
                      headers = list(),
                      ...) {

  if (identical(key, "") | identical(secret, "")) {
    stop("Please set application id and password using set_secret_key(key='key',
                                                            secret='secret')).")
  }
  
  # locate and validate credentials
  credentials <- locate_credentials(key = key, 
                                    secret = secret, 
                                    session_token = session_token, 
                                    region = region, 
                                    verbose = verbose)

  key <- credentials[["key"]]
  secret <- credentials[["secret"]]
  session_token <- credentials[["session_token"]]
  region <- credentials[["region"]]

  hostname <- paste0("awis.", region, ".amazonaws.com")
  current <- Sys.time()
  header_timestamp <- format(current, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  canonical_headers <- c(list(host = hostname,
                              `x-amz-date` = header_timestamp), headers)

  # generate signatures
  Sig <- signature_v4_auth(datetime = format(current,
                                             "%Y%m%dT%H%M%SZ", tz = "UTC"),
                           region = region,
                           service = "awis",
                           verb = "GET",
                           action = "/api",
                           query_args = query,
                           canonical_headers = canonical_headers,
                           request_body = "",
                           key = key,
                           secret = secret,
                           session_token = session_token,
                           verbose = verbose)

  headers[["x-amz-date"]] <- header_timestamp
  headers[["x-amz-content-sha256"]] <- Sig$BodyHash
  if (!is.null(session_token) && session_token != "") {
    headers[["x-amz-security-token"]] <- session_token
  }
  headers[["Authorization"]] <- Sig[["SignatureHeader"]]
  H <- do.call(add_headers, headers)
  
  res <- GET("https://awis.amazonaws.com/api", H, query = query)
  
  alexa_check(res)
  res <- as_list(read_xml(content(res, as = "text", encoding = "utf-8")))

  result <- alexa_PROCESS(res)
  result
}

#'
#' Postprocess the results a bit
#' 
#' @param  res result
#' @return display request ID and Response Status and the first member of the list 

alexa_PROCESS <- function(res) {

  cat("Request ID: ", unlist(res[[1]]$Response$OperationRequest$RequestId[[1]]), "\n")
  cat("Response Status: ", unlist(res[[1]]$Response$ResponseStatus$StatusCode[[1]]), "\n")

  res[[1]]
}

#'
#' Request Response Verification
#' 
#' @param  req request
#' @return in case of failure, a message

alexa_check <- function(req) {

  if (req$status_code < 400) {
    return(invisible())
  }

  stop("HTTP failure: ", req$status_code, "\n", call. = FALSE)
}
