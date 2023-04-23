import fs from 'fs';
import path from 'path';

const configPath = path.join(__dirname, '.', 'deployment.json');

export type ConfigType = {
    [contractName: string]: {
      address: string
    };
};

export function read(): ConfigType {
    if (fs.existsSync(configPath)) {
      return JSON.parse(fs.readFileSync(configPath, 'utf8'));
    } else {
      return {};
    }
}

export function write(newData: ConfigType) {
    fs.writeFileSync(configPath, JSON.stringify(newData));
}