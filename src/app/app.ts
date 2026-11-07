import { Component, signal } from '@angular/core';
import { RouterOutlet } from '@angular/router';

import { version } from '../../package.json';

@Component({
  imports: [RouterOutlet],
  selector: 'app-root',
  styleUrl: './app.scss',
  templateUrl: './app.html',
})
export class App {
  protected readonly title = signal('handson-yousuf');
  protected readonly version = version;
}
