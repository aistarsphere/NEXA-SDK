.PHONY: bootstrap gen check format example gateway e2e
bootstrap: ; ./tool/bootstrap.sh
gen:       ; ./tool/gen.sh
check:     ; ./tool/check.sh
format:    ; dart format packages apps tools
gateway:   ; ./tool/gateway.sh
e2e:       ; ./tool/e2e.sh
example:   ; cd apps/nexa_example && flutter run
