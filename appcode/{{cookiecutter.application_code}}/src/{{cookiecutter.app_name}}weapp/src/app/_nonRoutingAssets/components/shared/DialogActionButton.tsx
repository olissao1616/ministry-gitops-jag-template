import React, { ReactNode } from 'react';
import Button from '@mui/material/Button';
import {ButtonProps} from '@mui/material';

interface DialogActionButtonProps extends ButtonProps {
    text?: string;
    children?: ReactNode;
    onClick: () => void;
    color: 'inherit' | 'primary' | 'secondary' | 'success' | 'error' | 'info'  | 'warning';
    variant: 'text' | 'outlined' | 'contained';
}

const DialogActionButton: React.FC<DialogActionButtonProps> = ({ text, children, onClick, color, variant, ...otherProps }): ReactNode => (
        <Button
            color={color}
            variant={variant}
            onClick={onClick}
            sx={{ "{{" }}
                fontSize: '1rem',
                fontWeight: 'bold',
                borderWidth: 2,
                borderStyle: 'solid',
                '&:hover': {
                    borderWidth: 2,
                },
            {{ "}}" }}
            {...otherProps}
        >
            {text || children}
        </Button>
    );

// };

export default DialogActionButton;