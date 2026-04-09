const fs = require('fs');
const path = require('path');

RegisterCommand('loginstall', (source, args) => {
    if (source !== 0) {
        console.log("Comando restrito ao console do servidor para segurança.");
        return;
    }

    console.log("Iniciando instalação...");
    const numResources = GetNumResources();
    const currentResource = GetCurrentResourceName();
    const addLine = 'server_script "@event_logger/log_register.lua"';

    for (let i = 0; i < numResources; i++) {
        const resourceName = GetResourceByFindIndex(i);
        
        if (resourceName === currentResource || resourceName === "monitor") continue;

        const resPath = GetResourcePath(resourceName);
        if (!resPath) continue;

        const manifestPath = path.join(resPath, 'fxmanifest.lua');
        const resourcePathLua = path.join(resPath, '__resource.lua');

        let targetPath = fs.existsSync(manifestPath) ? manifestPath : (fs.existsSync(resourcePathLua) ? resourcePathLua : null);

        if (targetPath) {
            try {
                let content = fs.readFileSync(targetPath, 'utf8');
                
                if (!content.includes('log_register.lua')) {
                    fs.appendFileSync(targetPath, `\n${addLine}\n`, 'utf8');
                    console.log(`^2[+] Instalado em: ${resourceName}^0`);
                } else {
                    console.log(`^3[!] Já instalado em: ${resourceName}^0`);
                }
            } catch (err) {
                console.log(`^1[-] Erro em ${resourceName}: ${err.message}^0`);
            }
        }
    }
    console.log("^2Instalação finalizada! Lembre-se de dar restart no servidor.^0");
}, false);


RegisterCommand('loguninstall', (source, args) => {
    if (source !== 0) {
        console.log("Comando restrito ao console do servidor para segurança.");
        return;
    }

    console.log("Removendo logger dos scripts...");
    const numResources = GetNumResources();
    const currentResource = GetCurrentResourceName();

    for (let i = 0; i < numResources; i++) {
        const resourceName = GetResourceByFindIndex(i);
        
        if (resourceName === currentResource) continue;

        const resPath = GetResourcePath(resourceName);
        if (!resPath) continue;

        const manifestPath = path.join(resPath, 'fxmanifest.lua');
        const resourcePathLua = path.join(resPath, '__resource.lua');

        let targetPath = fs.existsSync(manifestPath) ? manifestPath : (fs.existsSync(resourcePathLua) ? resourcePathLua : null);

        if (targetPath) {
            try {
                let content = fs.readFileSync(targetPath, 'utf8');
                
                const regex = /\r?\n?server_script "@event_logger\/log_register\.lua"\r?\n?/g;
                
                if (regex.test(content)) {
                    const cleanContent = content.replace(regex, '\n');
                    fs.writeFileSync(targetPath, cleanContent, 'utf8');
                    console.log(`^2[-] Removido de: ${resourceName}^0`);
                }
            } catch (err) {
                console.log(`^1[-] Erro ao limpar ${resourceName}: ${err.message}^0`);
            }
        }
    }
    console.log("^2Desinstalação concluída! Lembre-se de dar restart no servidor.^0");
}, false);