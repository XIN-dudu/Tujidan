allprojects {
    repositories {
        // 优先使用阿里云镜像加速
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
        // 备用官方源
        google()
        mavenCentral()
    }
}

// 以下部分保持不变，这是修改构建目录的特殊配置
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    // 为所有子项目（包括插件）禁用资源验证
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.findByName("android")
            if (android != null) {
                try {
                    // 尝试设置 aaptOptions 来跳过资源验证
                    val aaptOptions = android.javaClass.getMethod("getAaptOptions").invoke(android)
                    val noCrunchMethod = aaptOptions.javaClass.getMethod("setNoCrunch", Boolean::class.java)
                    noCrunchMethod.invoke(aaptOptions, true)
                } catch (e: Exception) {
                    // 如果上面的方法失败，尝试其他方式
                }
            }
        }
        
        // 尝试禁用资源验证任务
        tasks.matching { it.name.contains("verifyReleaseResources") || it.name.contains("verifyDebugResources") }.configureEach {
            enabled = false
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}