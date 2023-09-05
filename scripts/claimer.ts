import { deploy } from "./deploymentLib";
async function main() {
    await deploy("ClaimAllImplementation", []);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

