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
    val image_files = csv("index.csv").circular
    val specs = csv("specs.csv").records
    val edits = csv("edits.csv").records

    val rnd = new scala.util.Random(42)

    val upload =
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

    val thumbnail =
      group("Thumbnail") {
        exec((session) => {
          session.set("spec", specs(rnd.nextInt(specs length)))
        })
        .exec(flattenMapIntoAttributes("${spec}"))
        .group("Image") {
          exec(
            http("${name}")
            .get("/iss/v2/thumbnails/pictures${store_path}?operation=${operation}&width=${width}&height=${height}&options=${options}")
            .check(
              status.is(200),
              headerRegex("Content-Type", "^image/")
            )
          )
        }
      }

    val thumbnail_data_uri =
      group("Thumbnail") {
        exec((session) => {
          session.set("spec", specs(rnd.nextInt(specs length)))
        })
        .exec(flattenMapIntoAttributes("${spec}"))
        .group("Data URI") {
          exec(
            http("${name}")
            .get("/iss/v2/thumbnails/pictures${store_path}?operation=${operation}&width=${width}&height=${height}&options=${options}&data-uri=true")
            .check(
              status.is(200),
              header("Content-Type").is("text/uri-list"),
              substring(";base64,")
            )
          )
        }
      }

    val edit =
      group("Edit") {
        exec((session) => {
          session.set("edit", edits(rnd.nextInt(edits length)))
        })
        .exec(flattenMapIntoAttributes("${edit}"))
        .exec(
          http("${name}")
          .get("/iss/v2/thumbnails/pictures${store_path}?operation=fit&width=165&height=165&rotate=${rotate}&crop_x=${crop_x}&crop_y=${crop_y}&crop_w=${crop_w}&crop_h=${crop_h}&edits=${edits}")
          .check(
            status.is(200),
            headerRegex("Content-Type", "^image/")
          )
        )
      }
  }

  val httpImageStore = http.baseURL(sys.env("HTTP_IMAGE_STORE_ADDR"))
    .disableWarmUp
    .disableCaching

  val upload_and_process = scenario("Upload and process images")
    .exec(ImageStore.health_check)
    .exitHereIfFailed
    .forever {
      exec(
        FlexiAPI.upload.pause(50 millisecond, 200 millisecond),
        repeat(10) {
          exec(
            FlexiAPI.thumbnail.pause(50 millisecond, 200 millisecond),
            FlexiAPI.thumbnail_data_uri.pause(50 millisecond, 200 millisecond),
            FlexiAPI.edit.pause(50 millisecond, 200 millisecond)
          )
        }
      )
    }

  setUp(
    upload_and_process.inject(rampUsers(sys.env("MAX_USERS").toInt) over (300 seconds)).protocols(httpImageStore)
  ).maxDuration(300 seconds)
  .assertions(
    global.failedRequests.percent.is(0),
    details("Upload image").responseTime.percentile3.lessThan(250),
    details("Thumbnail").responseTime.percentile3.lessThan(400),
    details("Edit").responseTime.percentile3.lessThan(600)
  )
}

