import { Component, OnInit, ChangeDetectorRef } from '@angular/core';
declare var cordova;
@Component({
  selector: 'app-home',
  templateUrl: 'home.page.html',
  styleUrls: ['home.page.scss'],
})
export class HomePage implements OnInit {

  isMicrophoneActive = false;

  constructor(private cd: ChangeDetectorRef) {
  }
  
  ngOnInit() {
  }

  callCordova() {
    const audioBytecodeBufferArray = [];
    cordova.plugins.AudioVolume.coolMethod('Hello world', rawData => {
      if (rawData !== null) {
        audioBytecodeBufferArray.push(rawData);
        this.isMicrophoneActive = true;
        this.cd.detectChanges();
        setTimeout(() => {
          this.isMicrophoneActive = false;
          this.cd.detectChanges();
        }, 100);
      }
    }, y => console.error(y));
  }

}
