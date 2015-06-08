import io.gatling.core.Predef._
import io.gatling.http.Predef._
import scala.concurrent.duration._

class LoadTest extends Simulation {
  object ImageStore {
    val health_check = exec(
      http("Health check")
        .get("/health_check")
        .check(
          status.is(200),
          bodyString.is("HTTP Image Store OK\r\n")
        )
    )
  }

  object FlexiAPI {
    val image_files = csv("index-1k.csv")
    val thumbnailing_specs = csv("thumbnail_specs_v2.csv").records

    val upload_and_thumbnail =
      repeat(200) {
        feed(image_files)
        .exec(
          http("Upload image")
          .post("/iss/v2/thumbnails/pictures/${file_name}")
          .body(RawFileBody("${file_name}"))
          .check(
            status.is(200),
            regex(""".+\.jpg$"""),
            regex("""([^\r]+)""").saveAs("store_path")
          )
        )
        .foreach(thumbnailing_specs, "spec") {
          exec(flattenMapIntoAttributes("${spec}"))
          .exec(
            http("Get thumbnail")
            .get("/iss/v2/thumbnails/pictures${store_path}?operation=${operation}&width=${width}&height=${height}&options=${options}")
            .check(
              status.is(200),
              headerRegex("Content-Type", "^image/")
            )
          )
          .exec(
            http("Get thumbnail (data URI)")
            .get("/iss/v2/thumbnails/pictures${store_path}?operation=${operation}&width=${width}&height=${height}&options=${options}&data-uri=true")
            .check(
              status.is(200),
              header("Content-Type").is("text/uri-list"),
              substring(";base64,")
            )
          )
        }
    }
  }

  val httpImageStore = http.baseURL("http://127.0.0.1:3050")

  val upload_and_thumbnail = scenario("Upload and thumbnail images")
    .exec(ImageStore.health_check)
    .exitHereIfFailed
    .exec(FlexiAPI.upload_and_thumbnail)

  setUp(
    upload_and_thumbnail.inject(rampUsers(5) over (1 seconds)).protocols(httpImageStore)
  )
  .assertions(details("Health check").failedRequests.percent.is(0))
}

