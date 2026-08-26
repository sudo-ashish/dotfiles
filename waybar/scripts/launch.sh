#!/bin/bash

pkill waybar
pkill swaync
pkill swayosd-server

waybar &
swaync &
swayosd-server &
