import { upgrade } from "./deploymentLib";
async function main() {
    await upgrade("bVaraImplementation", []);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

