import io.gatling.core.Predef._
import io.gatling.http.Predef._
import scala.concurrent.duration._

class LoadTest extends Simulation {
  object ImageStore {
    val root = exec(
      http("Root page")
        .get("/")
        .check(
          status.is(200),
          bodyString.is("HTTP Image Store\r\n")
        )
    )

    val health_check = exec(
      http("Health check")
        .get("/health_check")
        .check(
          status.is(200),
          bodyString.is("HTTP Image Store OK\r\n")
        )
    )
  }

  object Thumbnailer {
    val check_images_loaded = exec(
      http("Loaded Images Check")
        .get("/stats")
        .check(
          substring("images_loaded: 0\r\n")
        )
    )
  }

  object FlexiAPI {
    val image_files = csv("/Users/wcc/Documents/test_data/tatoos-100.csv")
    val thumbnailing_specs = csv("thumbnail_specs_v2.csv")

    val upload =
      feed(image_files)
      .exec(
        http("Upload image")
        .post("/iss/v2/thumbnails/pictures/${file_name}")
        .body(RawFileBody("/Users/wcc/Documents/test_data/${file_name}"))
        .check(
          status.is(200),
          regex(""".+\.jpg$"""),
          regex("""([^\r]+)""").saveAs("store_path")
        )
      )
      .repeat(10) {
        feed(thumbnailing_specs)
        .exec(
          http("Get thumbnail")
          .get("/iss/v2/thumbnails/pictures/${store_path}?operation=${operation}&width=${width}&height=${height}&options=${options}")
          .check(
            status.is(200),
            headerRegex("Content-Type", "^image/")
          )
        )
        .exec(
          http("Get thumbnail (data URI)")
          .get("/iss/v2/thumbnails/pictures/${store_path}?operation=${operation}&width=${width}&height=${height}&options=${options}&data-uri=true")
          .check(
            status.is(200),
            header("Content-Type").is("text/uri-list"),
            substring(";base64,")
          )
        )
      }
  }

  val httpImageStore = http .baseURL("http://localhost:3000")
  val httpThumbnailer = http .baseURL("http://localhost:3100")

  val check = scenario("Image Store Check").exec(
    ImageStore.root,
    ImageStore.health_check
  )

  val check_images_loaded = scenario("Check if we don't leak images").exec(
    Thumbnailer.check_images_loaded
  )

  val upload = scenario("Upload images").exec(
    FlexiAPI.upload
  )

  setUp(
    upload.inject(atOnceUsers(1)).protocols(httpImageStore)
    //check.inject(atOnceUsers(1)).protocols(httpImageStore),
    //check_images_loaded.inject(atOnceUsers(1)).protocols(httpThumbnailer)
  )
}

