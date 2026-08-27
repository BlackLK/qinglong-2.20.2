const tar = require("tar");
const fs = require("fs");

async function main() {
    await extractAndDelete("build/out.tar");
    await extractAndDelete("build/out-armv7.tar", 4);
    await extractAndDelete("build/out-alpine.tar");
}
main();

async function extractAndDelete(filename, stripCount = 5) {
    await tar.extract({
        file: filename,
        cwd: "./build",
        strip: stripCount,           //    linux_arm64\app\build\stage\v15.0.6\         Stripe 5 folders!!
        filter: (path) => {
            if (path.includes("app/build/stage/") && path.endsWith(".tar.gz")) {
                console.log(path);
                return true;
            }
            return false;
        }
    });

    fs.unlinkSync(filename);
}
