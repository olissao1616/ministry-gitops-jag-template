import { LocalizationProvider } from "@mui/x-date-pickers/LocalizationProvider";
import { AdapterDateFns } from "@mui/x-date-pickers/AdapterDateFnsV3";
import { DatePicker, DateValidationError } from "@mui/x-date-pickers";
import { useEffect, useMemo, useState } from "react";
import { DF_LEA_STANDARD } from "../lib/dateUtils";

interface DatePickerCalendarProps {
    width?: number;
    placeholder?: string;
    format?: string;
    value?: string | null;
    onChange?: (value: string | null) => void; 
    error?: boolean | undefined;
    errorMessage?: string | null;
}

const customLocaleText = {
    fieldYearPlaceholder: (params:any) => 'YYYY',
    fieldMonthPlaceholder: () => 'MMM',
    fieldDayPlaceholder: () => 'DD',
    fieldWeekDayPlaceholder: (params:any) => (params.contentType === 'letter' ? 'EEEE' : 'EE'),
    fieldHoursPlaceholder: () => 'hh',
    fieldMinutesPlaceholder: () => 'mm',
    fieldSecondsPlaceholder: () => 'ss',
    fieldMeridiemPlaceholder: () => 'aa',
};

export default function CustomDatePicker({ placeholder = DF_LEA_STANDARD, 
    format = DF_LEA_STANDARD, value, width = 300, onChange, error, errorMessage}: DatePickerCalendarProps) {
    
    const [cleared, setCleared] = useState<boolean>(false);

    useEffect(() => {
        //console.log("error: ", error, errorMessage);
    }, [error, errorMessage]);

    useEffect(() => {
        if (cleared) {
          const timeout = setTimeout(() => {
            setCleared(false);
          }, 1500);    
          return () => clearTimeout(timeout);
        }
        return () => {};
    }, [cleared]);

    return (
        <LocalizationProvider dateAdapter={AdapterDateFns} localeText={customLocaleText}>
            <DatePicker
                format={format}
                onChange={onChange}
                value={value}
                slotProps={{ "{{" }}
                    field: { clearable: true, onClear: () => setCleared(true) },
                    textField: {
                        sx: {
                            //textTransform: 'uppercase',
                            width: {width},
                        },
                        error: error,
                        helperText: errorMessage,
                        placeholder: placeholder,
                        autoComplete: 'new-password'
                    }
                {{ "}}" }}
            />
        </LocalizationProvider>
    );
};