import * as vscode from 'vscode';
import { join, dirname } from 'path';
import * as fs from 'fs';

export function activate(context: vscode.ExtensionContext) {

	console.log('Congratulations, your extension "racket-format" is now active!');

	let disposable = vscode.languages.registerDocumentFormattingEditProvider('racket', {
		provideDocumentFormattingEdits(document: vscode.TextDocument): any {
			const start = new vscode.Position(0, 0);
			const end = new vscode.Position(document.lineCount - 1, document.lineAt(document.lineCount - 1).text.length);
			const code = document.getText();

			const tmpFileName = rndName() + ".rkt";
			const tmpFile = join(dirname(document.fileName), tmpFileName);
			fs.writeFileSync(tmpFile, code);

			let myExtDir = vscode.extensions.getExtension("gkqha.racket-format")?.extensionPath;
			let command = `${myExtDir}\\out\\racket-format\\racket-format.rkt`;
			console.log(`command${command}`);

			const { spawnSync } = require('child_process');
			const child = spawnSync('racket', [command, tmpFile], { input: 'text', encoding: 'utf8' });
			const { stderr, stdout } = child;
			fs.unlinkSync(tmpFile);
			return [vscode.TextEdit.replace(new vscode.Range(start, end), stdout)];
		}
	});

	const rndName = () => {
		return Math.random().toString(36).replace(/[^a-z]+/g, "").substr(0, 10);
	};


	context.subscriptions.push(disposable);
}

export function deactivate() { }
