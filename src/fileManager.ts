import * as vscode from 'vscode';
import { join, dirname } from 'path';
import * as fs from 'fs';


export class FileManager {
    private _outputChannel: vscode.OutputChannel;
    private _isRunning!: boolean;
    private _process: any;
    private _tmpFile!: string;
    private _cwd!: string;
    private _myExtDir: string | undefined;
    private editor: any;
    private _stdout!: string;

    constructor() {
        this._outputChannel = vscode.window.createOutputChannel('Format');
        this._myExtDir = vscode.extensions.getExtension("gkqha.racket-format")?.extensionPath;
    }

    private initialize(): void {
        this.editor = vscode.window.activeTextEditor;
        if (!this.editor.document.isUntitled) {
            this._cwd = dirname(this.editor.document.fileName);
        }
    }

    public run(): string {
        this.initialize();

        // if (this._isRunning) {
        //     vscode.window.showInformationMessage('Code is already running!');
        //     return "";
        // }

        let code = this.getCode();
        // if (!code) {
        //     vscode.window.showInformationMessage('No code found or selected.');
        //     return "";
        // }
        if (code) {
            this.createRandomFile(code);
        }

        return this.executeCommand();
    }

    private getCode(): string | null {
        if (!this.editor) {
            return null;
        }

        let text = this.editor.document.getText();

        return text;
    }

    private rndName(): string {
        return Math.random().toString(36).replace(/[^a-z]+/g, "").substr(0, 10);
    }

    private createRandomFile(content: string) {
        let fileName = vscode.window.activeTextEditor?.document.fileName;

        let fileType = '.rkt';
        let tmpFileName = this.rndName() + fileType;
        this._tmpFile = join(this._cwd, tmpFileName);

        fs.writeFileSync(this._tmpFile, content);
    }

    private executeCommand(): any {
        this._isRunning = true;
        this._outputChannel.show();
        this._outputChannel.appendLine('>> Running ');
        let exec = require('child_process').exec;
        let command = `racket ${this._myExtDir}\\out\\racket-format\\racket-format.rkt ${this._tmpFile}`;
        console.log(`command${command}`);

        this._process = exec((command), (error: string, stdout: string, stderr: string) => {
            if (error) {
                console.error(`error: ${error}`);
            }
            console.log(`stdout: ${stdout}`);
            this._stdout = stdout;
            this._isRunning = false;
            this._outputChannel.appendLine('');
            this._outputChannel.appendLine('[Done]');
            this._outputChannel.appendLine('');
            fs.unlinkSync(this._tmpFile);
            console.log(this._stdout);
            return this._stdout;
        });
    }
}