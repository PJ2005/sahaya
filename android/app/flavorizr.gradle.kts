import com.android.build.gradle.AppExtension

val android = project.extensions.getByType(AppExtension::class.java)

android.apply {
    flavorDimensions("flavor-type")

    productFlavors {
        create("ngo") {
            dimension = "flavor-type"
            applicationId = "com.sahaya.ngo"
            resValue(type = "string", name = "app_name", value = "Sahaya NGO")
        }
        create("volunteer") {
            dimension = "flavor-type"
            applicationId = "com.sahaya.volunteer"
            resValue(type = "string", name = "app_name", value = "Sahaya Volunteer")
        }
    }
}